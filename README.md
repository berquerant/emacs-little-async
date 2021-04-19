# Little things async

Small asynchronous process execution library for myself.

## Usage

``` emacs-lisp
(little-async-start-process "grep -o . | while read c ; do sleep 0.2 ; echo $c ; done"
                            :input "Hello!"
                            :filter (lambda (p output)
                                      (with-current-buffer
                                          (get-buffer-create "*tmp*")
                                        (insert (format "GOT %s" output)))))
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

Each line is written every 0.2 seconds.
