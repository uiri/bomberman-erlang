#!/usr/bin/env escript
-module(ai).
-export([main/1]).

move(Sock) ->
    receive
        {ok, Json} ->
	    {X, Y} = bomberman:coords(Json),
	    Board = bomberman:board(Json),
	    io:fwrite(bomberman:cell(Board, X, Y)),
	    io:fwrite("\n"),
	    Pick = random:uniform(4),
	    if
	        Pick =:= 1 -> bomberman:up(Sock);
		Pick =:= 2 -> bomberman:down(Sock);
		Pick =:= 3 -> bomberman:left(Sock);
		Pick =:= 4 -> bomberman:right(Sock)
	    end,
            move(Sock);
        {error, closed} ->
            gen_tcp:close(Sock)
    end.

main(_) ->
    Sock = bomberman:player("localhost", 40000, self()),
    move(Sock).
