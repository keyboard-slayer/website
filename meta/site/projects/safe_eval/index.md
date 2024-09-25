# A new sandbox for Odoo

You can find the source code for this project [here](https://github.com/keyboard-slayer/odoo-eval/blob/master-safe_eval_redo-joda/odoo/tools/safe_eval.py)


If you want to compare it with the original implementation, you can find it [here](https://github.com/odoo/odoo/blob/17.0/odoo/tools/safe_eval.py)

## 1. Introduction
If you are not aware of what Odoo is / does, you can check out their website [here](https://www.odoo.com/). Odoo is a suite of open source business apps that cover all your company needs: CRM, eCommerce, accounting, inventory, point of sale, project management, etc.

Odoo is quite cool and has a lot of features. One very cool feature that powerusers likes is the ability to write python code to do some automations. This is done in the form of [server actions](https://www.odoo.com/documentation/17.0/developer/reference/backend/actions.html#server-actions-ir-actions-server), most users will interact with this feature through a UI that is now hidden in the debug mode.

You can see the feature in action in the [video](https://www.youtube.com/watch?v=dmHGZD6xfnA) of [Odooityourself](https://www.youtube.com/@odoo-it-yourself)

## 2. How does it work?
If you pay attention to the introduction, you might ask yourself, isn't it a bad idea to allow users to execute arbitrary python code on the server? I would say yes, but Odoo thought otherwise and they implemented a sandboxed environment to run the code. The implementation is in the file `odoo/tools/safe_eval.py` and it is quite complex at first glance.

Let me introduce you to this version of the safe_eval.py file.

### How the original implementation works
Here are the steps that the original implementation takes to run the code:

0. Your code is passed to the `safe_eval`, the sandbox function, with a very limited set of builtins and globals. Your environment will have [Those lines](https://github.com/odoo/odoo/blob/0b308699d089dc2f2b39c756ce05e58003c1b2f3/odoo/tools/safe_eval.py#L303-L340) as builtins and the globals are mostly defined by the caller of the function. In the case of a server action, the caller function will give an instance of Odoo's [Environment](https://www.odoo.com/documentation/17.0/developer/reference/backend/orm.html?highlight=env#environment). So that the code can have access to the ORM.

1. Your code will be compiled as CPython bytecode using the `compile` function[*](https://github.com/odoo/odoo/blob/0b308699d089dc2f2b39c756ce05e58003c1b2f3/odoo/tools/safe_eval.py#L252).

2. It will check if you done use any forbidden operations, such as:
    - Making an import statement[*](https://github.com/odoo/odoo/blob/0b308699d089dc2f2b39c756ce05e58003c1b2f3/odoo/tools/safe_eval.py#L81).
    - Modifing or deleting the attribute of an object[*](https://github.com/odoo/odoo/blob/0b308699d089dc2f2b39c756ce05e58003c1b2f3/odoo/tools/safe_eval.py#L84).
    - Modifing or deleting a global variable[*](https://github.com/odoo/odoo/blob/0b308699d089dc2f2b39c756ce05e58003c1b2f3/odoo/tools/safe_eval.py#L86).

3. It will check if you don't use any variable with a double underscore in the name (called dunder names)[*](https://github.com/odoo/odoo/blob/0b308699d089dc2f2b39c756ce05e58003c1b2f3/odoo/tools/safe_eval.py#L202-L205).

### What is wrong with it?
Can you spot the issue ? No ? Let me show it to you with a simple example.

Take a look at [this commit](https://github.com/odoo/odoo/commit/abbfd744360b39c41531dfd37423ee86bd40233d) and [this snippet](https://github.com/pallets/flask/blob/2fec0b206c6e83ea813ab26597e15c96fab08be7/src/flask/wrappers.py#L18-L32) from Werkzeug, a library that Odoo uses to make the HTTP server.

Still not sure ?
What if I told you by getting a `Response` object, you could execute arbitrary code on the server before this commit ?

> **Note**: If you are interested, I made a [docker-compose.yml](./docker-compose.yml) that includes the odoo source code exactly before this patch was commited. You can also revert the commit and see the vulnerability in action.

``` python
raise UserError(env['ir.http']._redirect('/').json_module.codecs.sys.modules['builtins'].open('/etc/passwd').read())
```

Let's dissect this code:

- `env['ir.http']._redirect('/')` will return a response object[*](https://github.com/odoo/odoo/blob/8a4b56fb1de80f701d8cd2d88d6f330814ea46b5/odoo/addons/base/models/ir_http.py#L246-L248)
- `json_module` will gives us access to the **unwrap** json module.
- With this, we can access the `sys` module by accessing the `codecs` module.
- Once we have the `sys` module, it's game over. We can access every functionality of the python interpreter. In this case, we ask the builtins module to give us the `open` function. You heard it right, the plain old `open` function.

🎉 We can read `/etc/passwd` without any problem. Leaking `/etc/passwd` is an example, but in a multi-tenant settings (like Odoo's SaaS), this exploit could leak secret from other client or secrets from Odoo directly.

## 3. Where I come in

During my internship at Odoo, I was tasked to make `safe_eval` more secure by doing one simple thing: check the input and output of every function calls, while remaning fully backwards compatible. At first, you might think that this is a simple task, but it's not. We were still using Python 3.7, we didn't have any of the monitoring tools that are available nowaday, and absolutely nobody was using type hints. After a few weeks of research, I came up with a solution that could potentially work, re-writing the whole `safe_eval` function by using the `ast` module. This is done by injecting checks ahead of time.

Here a quick overview of the steps that I took to make it work:

0. The caller of the function can limit the *ast nodes* a user can use. But it cannot accept every nodes, in fact it only accept a node present in [this whitelist](https://github.com/keyboard-slayer/odoo-eval/blob/2dad991bab9e68361bd9150879f12f2af8fe1499/odoo/tools/safe_eval.py#L164-L253)
1. Every global variable that are passed to the sandboxed are checked to see if they don't contain dunder names.[*](https://github.com/keyboard-slayer/odoo-eval/blob/2dad991bab9e68361bd9150879f12f2af8fe1499/odoo/tools/safe_eval.py#L740-L743) This is done because the way dictionaries are implemented in Python, you can re-call an evaluation inside of the sandbox and leak dunder names quite easily (All there is to do is making an entry into the `ir.actions.server` model and run it).
2. It will explore every `ast` nodes recursively and adds checks, for example:
    * Is the current node in the whitelist ?[*](https://github.com/keyboard-slayer/odoo-eval/blob/2dad991bab9e68361bd9150879f12f2af8fe1499/odoo/tools/safe_eval.py#L425-L428)
    * If it's a function definition or a variable declaration, do we allow the name ?[*](https://github.com/keyboard-slayer/odoo-eval/blob/2dad991bab9e68361bd9150879f12f2af8fe1499/odoo/tools/safe_eval.py#L435-L442)
    * If we try to access a variable, is its name allowed ?[*](https://github.com/keyboard-slayer/odoo-eval/blob/2dad991bab9e68361bd9150879f12f2af8fe1499/odoo/tools/safe_eval.py#L463-L466)
    * If we try to access an attribute, is it an allowed name? If yes we wrap it with a simple type checker.[*](https://github.com/keyboard-slayer/odoo-eval/blob/2dad991bab9e68361bd9150879f12f2af8fe1499/odoo/tools/safe_eval.py#L468-L475). The type checker is a simple function that will check how a type is used and if it's on the right whitelist[*](https://github.com/keyboard-slayer/odoo-eval/blob/2dad991bab9e68361bd9150879f12f2af8fe1499/odoo/tools/safe_eval.py#L91-L162).
    * If try to make a function call, we need to check if the function is allowed, if the arguments and keywords are type safe and if the return value is type safe too.[*](https://github.com/keyboard-slayer/odoo-eval/blob/2dad991bab9e68361bd9150879f12f2af8fe1499/odoo/tools/safe_eval.py#L477-L504)
    * And a lot more...
3. The code is compiled and then executed as before BUT with all the checks that we added inlined in the code.

> **Note**: Feel free to revert the mentioned commit and try to exploit the code with this version of Odoo. You will see that it's very hard to do so.

### What is the result ?

The results are quite good, we did an internal bugbounty. Only two bugs were found. One of them was a dumb mistake I made and the other one was a crazy bypass that is quite hard to exploit. After some more testing, we decided to give it to external security researchers and no bugs were found! But unfortunately, the code was never merged into the main branch of Odoo. The reason was, Olivier Dony, the Security Officer at Odoo, was not convinced that the code was more secure than the original implementation. While I can understand his point of view about on how complex this implementation is, I still think that this implementation is more secure than the original one. I also think that it's a good starting point for a more secure implementation. <p style="color: red">But, in a future article, I will show you why ultimately, every implementation of a sandboxed environment written in Python is doomed to fail (yes, even mine). And what's the future of Odoo's security if they stick with the same sandbox</p>