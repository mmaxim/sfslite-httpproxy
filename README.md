# sfslite HTTP Proxy

This is a little demo of how to use sfslite's (https://github.com/okws/sfslite) libasync and libtame to build a single threaded event-driven HTTP proxy. We take advantage of libtame and the tame preprocessor to write very clear and readable callback driven code. 

Tame (http://pdos.csail.mit.edu/papers/tame-usenix07.pdf) provides a framework for making event-driven non-blocking code easy to understand and write, and is the foundation for OkCupid.com's web infratructure.

# Building

In order to build this project, you first need to build and install sfslite to it's default install location (/usr/local/{include,lib}/sfslite). Once complete, simply type:

* make

If you do not have clang, then issue this command:

* make CXX=g++

To run, just type:

* ./proxy

To test, you can do:

* curl --proxy localhost:8080 www.google.com

Any questions/comments, email Mike Maxim (mike.maxim@gmail.com)
