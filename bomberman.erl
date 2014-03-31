-module(bomberman).
-export([player/3, recv/3, bomb/1, right/1, left/1, down/1, up/1, coords/1, board/1, cell/3, radius/1, alive/1, turn/1]).

cell(Board, X, Y) ->
    {Celllist} = lists:nth(Y+1, lists:nth(X+1, Board)),
    {_, Cell} = lists:nth(1, Celllist),
    Cell.

board(Json) ->
    proplists:get_value(<<"Board">>, Json).

coords(Json) ->
    {proplists:get_value(<<"X">>, Json),
     proplists:get_value(<<"Y">>, Json)}.

radius(Json) ->
    proplists:get_value(<<"MaxRadius">>, Json).

alive(Json) ->
    proplists:get_value(<<"Alive">>, Json).

turn(Json) ->
    proplists:get_value(<<"Turn">>, Json).

bomb(Sock) ->
    gen_tcp:send(Sock, "bomb\n"),
    "bomb\n".

right(Sock) ->
    gen_tcp:send(Sock, "right\n"),
    "right\n".

left(Sock) ->
    gen_tcp:send(Sock, "left\n"),
    "left\n".

down(Sock) ->
    gen_tcp:send(Sock, "down\n"),
    "down\n".

up(Sock) ->
    gen_tcp:send(Sock, "up\n"),
    "up\n".

recv(Sock, Client, Bins) ->
    case gen_tcp:recv(Sock, 0) of
	{ok, Bin} ->
	    Binlist = binary:split(<<Bins/binary, Bin/binary>>, <<"\n">>, [trim]),
	    Lastbyte = binary:last(Bin),   
	    case length(Binlist) of
		0 ->
		    recv(Sock, Client, <<>>);
		1 ->
		    if
			Lastbyte =:= 10 ->
			    try jiffy:decode(lists:nth(1, Binlist)) of
				{Json} -> Client ! {ok, Json}
			    catch {error, {_, truncated_json}} ->
				    recv(Sock, Client, lists:nth(1, Binlist))
			    end,
			    recv(Sock, Client, <<>>);
			true ->
			    recv(Sock, Client, lists:nth(1, Binlist))
		    end;
		2 ->
		    Firstofbinlist = lists:nth(1, Binlist),
		    Restofbinlist = lists:nth(2, Binlist),
		    try jiffy:decode(Firstofbinlist) of
			{Json} ->
			    Client ! {ok, Json},
			    if
				Lastbyte =:= 10 ->
				    recv(Sock, Client, <<>>);
				true ->
				    recv(Sock, Client, Restofbinlist)
			    end
		    catch {error, {_, truncated_json}} ->
			    recv(Sock, Client, <<Firstofbinlist/binary, Restofbinlist/binary>>)
		    end
	    end;
	{error, closed} ->
	    Client ! {error, closed}
    end.

player(Hostname, Port, Client) ->
    {ok, Sock} = gen_tcp:connect(Hostname, Port, [{active, false}, binary]),
    spawn(bomberman, recv, [Sock, Client, <<>>]),
    Sock.
