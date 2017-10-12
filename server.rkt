#lang racket/base

(require racket/string
         racket/udp)

(define DISCOVERY-PORT 3699)

(let ([sock (udp-open-socket #f DISCOVERY-PORT)]
      [buf (make-bytes 4096)])
  (udp-bind! sock #f DISCOVERY-PORT)
  (let loop ()
    (define-values (len host port) (udp-receive! sock buf))
    (define msg-str (string-trim (bytes->string/utf-8 buf #f 0 len) #:left? #f))
    (printf "~a[~a]: ~a\n" host port msg-str)

    (cond [(string=? msg-str "CONNECT") (printf "CONNECTING ~a ~a\n" host port)]
          [else (printf "bad message: ~a\n" msg-str)])

    (loop)))
