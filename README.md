# Little things async

Small asynchronous process execution library for myself.

## Usage

``` bash
# test.sh
#!/bin/bash
echo "to stderr" >&2
grep . -o | while read x ; do sleep 0.2 ; echo "$x" ; done
```

``` emacs-lisp
(little-async-start-process '("/path/to/test.sh")
                            :input "Hello!"
                            :filter (lambda (p output)
                                      (with-current-buffer
                                          (get-buffer-create "*tmp*")
                                        (insert (format "GOT %s" output))))
                            :stderr "*tmp-stderr*")
```

You will see below in `*tmp*` buffer:

```
GOT H
GOT e
GOT l
GOT l
GOT o
GOT !
```

Each line is written every 0.2 seconds. Meanwhile, Emacs will not be blocked.

You will see belo in `*tmp-stderr*` buffer:

```
to stderr
```
