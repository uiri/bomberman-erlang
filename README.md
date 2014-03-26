Bomberman-Erlang
================

This is a library for https://github.com/aybabtme/bomberman  
This relies on https://github.com/davidsp/jiffy to work. Make sure that his repo in is your ERL_LIBS somehow.


To start a player, you only need to call bomberman:player/3 (hereafter I'm dropping the bomberman: prefix) with Hostname (string), Port (integer), Client (process) as arguments. Client should probably be self() or the result of a spawn() call to your function which receives the messages and sends moves. up/1, down/1, left/1, right/1 and bomb/1 all take the Socket as arguments. The Socket is returned by the call to player() so you'll need a way to get it to the other process if you're not using self().


The way to write a client is to loop, waiting to receive an {ok, Json} message from bomberman. When you receive {error, closed} you'll probably want to exit and need to close the socket. board/1 and coords/1 take the Json from a message as their argument. coords/1 returns X, Y as a tuple. cell/3 takes a result from board as its first argument and X, Y returned from coords as its second and third arguments. Right now it just plucks the binary out of the board structure, but I may make it return an atom instead.


Open up random_ai.erl for a really short example AI script. I'm not sure how to package Erlang stuff so just have fun with it. If you get an error, please tell me, it is really difficult to make sure that I've caught a full JSON object recving off of the TCP socket.
