#lang racket/base

(require racket/string
         racket/udp)

(define PORT 3699)

(let ([sock (udp-open-socket "255.255.255.255" PORT)]
      [buf (make-bytes 4096)])
  (udp-bind! sock #f PORT)
  (let loop ()
    (define-values (len host port) (udp-receive! sock buf))
    (define msg-str (string-trim (bytes->string/utf-8 buf #f 0 len) #:left? #f))
    (printf "~a[~a]: ~a\n" host port msg-str)

    (cond [(string=? msg-str "PING") (udp-send-to sock host port #"PONG\n")]
          [(string=? msg-str "CONNECT") (printf "CONNECTING ~a ~a\n" host port)]
          [else (printf "bad message: ~a\n" msg-str)])

    (loop)))
