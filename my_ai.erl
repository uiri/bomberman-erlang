#!/usr/bin/env escript
-module(my_ai).
-export([main/1]).
%%! debug

find_bomb(Radius, Board, X, Y, Direction) ->
    Cell = bomberman:cell(Board, X, Y),
    Wallrock = [<<"Wall">>, <<"Rock">>, <<"Flame">>],
    Deadend = lists:member(Cell, Wallrock),
    if
	Cell =:= <<"Bomb">> ->
	    {run, X, Y};
	Deadend ->
	    {clear, 0, 0};
	Radius =:= 0 ->
	    {clear, 0, 0};
	Direction =:= up ->
	    find_bomb(Radius-1, Board, X, Y-1, up);
	Direction =:= down ->
	    find_bomb(Radius-1, Board, X, Y+1, down);
	Direction =:= left ->
	    find_bomb(Radius-1, Board, X-1, Y, left);
	Direction =:= right ->
	    find_bomb(Radius-1, Board, X+1, Y, right);
	true ->
	    {Upres, UpX, UpY} = find_bomb(Radius-1, Board, X, Y-1, up),
	    {Downres, DownX, DownY} = find_bomb(Radius-1, Board, X, Y+1, down),
	    {Leftres, LeftX, LeftY} = find_bomb(Radius-1, Board, X-1, Y, left),
	    {Rightres, RightX, RightY} = find_bomb(Radius-1, Board, X+1, Y, right),
	    if
		Upres =:= run ->
		    {run, UpX, UpY};
		Downres =:= run ->
		    {run, DownX, DownY};
		Leftres =:= run ->
		    {run, LeftX, LeftY};
		Rightres =:= run ->
		    {run, RightX, RightY};
		true ->
		    {clear, 0, 0}
	    end
    end.

%% random_move(Sock) ->
%%     Pick = random:uniform(4),
%%     if
%% 	Pick =:= 1 -> bomberman:up(Sock	Pick =:= 2 -> bomberman:down(Sock);
%% 	Pick =:= 3 -> bomberman:left(Sock);
%% 	Pick =:= 4 -> bomberman:right(Sock)
%%     end,
%%     move(Sock).

explore(Board, OldX, OldY, X, Y, Been) ->
    Wallrock = [<<"Wall">>, <<"Rock">>, <<"Flame">>],
    Thiscell = bomberman:cell(Board, X, Y),
    Deadend = lists:member(Thiscell, Wallrock),
    if
	Deadend ->
	    {deadend, OldX, OldY};
	true ->
	    Togo = [{X-1, Y}, {X+1, Y}, {X, Y-1}, {X, Y+1}],
	    Newbeen = sets:union(sets:from_list(Togo), Been),
	    Newtogo = lists:filtermap( fun({NewX, NewY}) ->
					       case sets:is_element({NewX, NewY}, Been) of
						   true ->
						       false;
						   false ->
						       {_, ExpX, ExpY} = explore(Board, X, Y, NewX, NewY, Newbeen),
						       {true, {ExpX, ExpY}}
					       end
				       end,
				       Togo),
	    if
		length(Newtogo) =:= 0 ->
		    {go, X, Y};
		true ->
		    {_, MaxX, MaxY} = maxdist(X, Y, Newtogo),
		    {go, MaxX, MaxY}
	    end
    end.

distance(Xo, Yo, X, Y) ->
    math:sqrt(abs(X*X - Xo*Xo) + abs(Y*Y - Yo*Yo)).

maxdist(X, Y, Pairs) ->
    Distlist = lists:map(fun({NewX, NewY}) -> {distance(X, Y, NewX, NewY), NewX, NewY} end,
			 Pairs),
    lists:nth(1, lists:reverse(lists:keysort(1, Distlist))).

next_move(Board, X, Y, Radius) ->
    case find_bomb(Radius+1, Board, X, Y, all) of
	{run, BombX, BombY} ->
	    {run, BombX, BombY};
	{clear, _, _} ->
	    {_, ExpX, ExpY} = explore(Board, X, Y, X, Y, sets:new()),
	    {go, ExpX, ExpY}
    end.

make_move(Sock, Json) ->
    {X, Y} = bomberman:coords(Json),
    Board = bomberman:board(Json),
    Radius = bomberman:radius(Json),
    case next_move(Board, X, Y, Radius) of
	{run, BombX, BombY} ->
	    run_away_from(Sock, Board, X, Y, BombX, BombY);
	{go, NewX, NewY} ->
	    %% io:fwrite("Travel to "),
	    %% io:write(NewX),
	    %% io:fwrite(","),
	    %% io:write(NewY),
	    %% io:nl(),
	    travel_to(Sock, Board, X, Y, NewX, NewY)
    end.

posorneg(A, B) ->
    if
	A < B ->
	    1; 
	A > B ->
	    -1;
	true ->
	    0
    end.

goleftright(Sock, Board, X, Y, NewX) ->
    Wallrock = [<<"Wall">>, <<"Rock">>, <<"Flame">>],
    if
	NewX > X ->
	    %% io:fwrite("I want to go right\n"),
	    Cell = bomberman:cell(Board, X, Y),
	    Deadend = lists:member(Cell, Wallrock),
	    %% io:write(Deadend),
	    %% io:nl(),
	    if
		Deadend ->
		    bomberman:left(Sock);
		true ->
		    bomberman:right(Sock)
	    end;
	NewX < X ->
	    %% io:fwrite("I want to go left\n"),
	    Cell = bomberman:cell(Board, X, Y),
	    Deadend = lists:member(Cell, Wallrock),
	    %% io:write(Deadend),
	    %% io:nl(),
	    if
		Deadend ->
		    bomberman:right(Sock);
		true ->
		    bomberman:left(Sock)
	    end;
	true ->
	    Pick = random:uniform(2),
	    if
		Pick =:= 1 -> bomberman:up(Sock);
		true -> bomberman:down(Sock)
	    end		      
    end.

goleftright(bomb, Sock, Board, X, Y, NewX) ->
    Wallrock = [<<"Wall">>, <<"Rock">>, <<"Flame">>],
    if
	NewX > X ->
	    Cell = bomberman:cell(Board, X+1, Y),
	    Deadend = lists:member(Cell, Wallrock),
	    if
		 Deadend ->
		    bomberman:right(Sock);
		true ->
		    bomberman:left(Sock)
	    end;
	NewX < X ->
	    Cell = bomberman:cell(Board, X-1, Y),
	    Deadend = lists:member(Cell, Wallrock),
	    if
		Deadend ->
		    bomberman:left(Sock);
		true ->
		    bomberman:right(Sock)
	    end;
	true ->
	    Pick = random:uniform(2),
	    if
		Pick =:= 1 -> bomberman:left(Sock);
		true -> bomberman:down(Sock)
	    end		      
    end.

goupdown(Sock, Board, X, Y, NewY) ->
    Wallrock = [<<"Wall">>, <<"Rock">>, <<"Flame">>],
    if
	NewY > Y ->
	    %% io:fwrite("I want to go down\n"),
	    Cell = bomberman:cell(Board, X, Y+1),
	    Deadend = lists:member(Cell, Wallrock),
	    %% io:write(Deadend),
	    %% io:nl(),
	    if
		Deadend ->
		    bomberman:up(Sock);
		true ->
		    bomberman:down(Sock)
	    end;
	NewY < Y ->
	    %% io:fwrite("I want to go up\n"),
	    Cell = bomberman:cell(Board, X, Y-1),
	    Deadend = lists:member(Cell, Wallrock),
	    %% io:write(Deadend),
	    %% io:nl(),
	    if
		Deadend ->
		    bomberman:down(Sock);
		true ->
		    bomberman:up(Sock)
	    end;
	true ->
	    Pick = random:uniform(2),
	    if
		Pick =:= 1 -> bomberman:left(Sock);
		true -> bomberman:right(Sock)
	    end
    end.

goupdown(bomb, Sock, Board, X, Y, NewY) ->
    Wallrock = [<<"Wall">>, <<"Rock">>, <<"Flame">>],
    if
	NewY > Y ->
	    Cell = bomberman:cell(Board, X, Y),
	    Deadend = lists:member(Cell, Wallrock),
	    if
		Deadend ->
		    bomberman:down(Sock);
		true ->
		    bomberman:up(Sock)
	    end;
	NewY < Y ->
	    Cell = bomberman:cell(Board, X, Y),
	    Deadend = lists:member(Cell, Wallrock),
	    if
		Deadend ->
		    bomberman:up(Sock);
		true ->
		    bomberman:down(Sock)
	    end;
	true ->
	    Pick = random:uniform(2),
	    if
		Pick =:= 1 -> bomberman:right(Sock);
		true -> bomberman:left(Sock)
	    end
    end.

next_travel(Sock, Board, X, Y, NewX, NewY, N) ->
    Wallrock = [<<"Wall">>, <<"Rock">>, <<"Flame">>],
    NextX = X+(N*posorneg(X, NewX)),
    NextY = Y+(N*posorneg(Y, NewY)),
    XCell = bomberman:cell(Board, NextX, Y),
    YCell = bomberman:cell(Board, X, NextY),
    Downorup = lists:member(XCell, Wallrock),
    Leftorright = lists:member(YCell, Wallrock),
    Xeq = X =:= NextX,
    Yeq = Y =:= NextY,
    %% io:write(X),
    %% io:fwrite(" - "),
    %% io:write(NextX),
    %% io:fwrite(" -- "),
    %% io:write(Y),
    %% io:fwrite(" - "),
    %% io:write(NextY),
    %% io:nl(),
    if
	(Yeq and Xeq) or (Downorup and Leftorright) ->
	    Pick = random:uniform(2),
	    if
		Pick =:= 1 -> goleftright(Sock, Board, X, Y, NewX);
		true -> goupdown(Sock, Board, X, Y, NewY)
	    end;
	Downorup -> goupdown(Sock, Board, X, Y, NewY);
	Leftorright -> goleftright(Sock, Board, X, Y, NewX);
	true -> next_travel(Sock, Board, X, Y, NewX, NewY, N+1)
    end.

travel_to(Sock, Board, X, Y, NewX, NewY) ->
    Xthere = X =:= NewX,
    Ythere = Y =:= NewY,
    if
	Xthere and Ythere -> bomberman:bomb(Sock);
	Xthere -> goupdown(Sock, Board, X, Y, NewY);
	Ythere -> goleftright(Sock, Board, X, Y, NewX);
	true -> next_travel(Sock, Board, X, Y, NewX, NewY, 1)
    end,
    receive
	{ok, Json} ->
	    {NextX, NextY} = bomberman:coords(Json),
	    NextBoard = bomberman:board(Json),
	    %% Xeq = NextX =:= NewX,
	    %% Yeq = NextY =:= NewY,
	    Farther = ((distance(NewX, NewY, X, Y) =< distance(NewX, NewY, NextX, NextY))
		       and (NewX =/= NextX) and (NewY =/= NextY)),
	    if
		%% Xeq and Yeq ->
		%%     bomberman:bomb(Sock),
		%%     run_away_from(Sock, NextBoard, NextX, NextY, NextX, NextY);
		Xthere and Ythere ->
		    run_away_from(Sock, NextBoard, NextX, NextY, NextX, NextY);
		Farther ->
		    if
			NextX =:= X ->
			    if
				NextY =:= Y ->
				    ExpX = -1,
				    ExpY = -1,
				    bomberman:bomb(Sock);
				NextY > Y ->
				    {_, ExpX, ExpY} = find_bomb(-1, Board, NextX, NextY, down);
				true ->
				    {_, ExpX, ExpY} = find_bomb(-1, Board, NextX, NextY, up)
			    end;
			true ->
			    if
				NextX > X ->
				    {_, ExpX, ExpY} = find_bomb(-1, Board, NextX, NextY, right);
				true ->
				    {_, ExpX, ExpY} = find_bomb(-1, Board, NextX, NextY, left)
			    end
		    end,
		    Negone = (ExpX =:= -1) and (ExpY =:= -1),
		    if
			Negone ->
			    run_away_from(Sock, NextBoard, NextX, NextY, NextX, NextY);
			true ->
			    travel_to(Sock, NextBoard, NextX, NextY, ExpX, ExpY)
		    end;
		true ->
		    travel_to(Sock, NextBoard, NextX, NextY, NewX, NewY)
	    end;
	{error, closed} ->
	    gen_tcp:close(Sock)
    end.

move(Sock) ->
    receive
	{ok, Json} ->
	    make_move(Sock, Json);
	{error, closed} ->
	    gen_tcp:close(Sock)
    end.

run_away_from(Sock, Board, X, Y, BombX, BombY) ->
    Wallrock = [<<"Wall">>, <<"Rock">>, <<"Bomb">>],
    Runaway = (X =:= BombX) and (Y =:= BombY),
    if
	Runaway ->
	    {_, RunX, RunY} = explore(Board, X, Y, X, Y, sets:new()),
	    %% io:fwrite("Explore to "),
	    %% io:write(RunX),
	    %% io:fwrite(","),
	    %% io:write(RunY),
	    %% io:nl(),
	    if
		RunX =:= X -> goupdown(Sock, Board, X, Y, RunY);
		RunY =:= Y -> goleftright(Sock, Board, X, Y, RunX);
		true ->
		    Pick = random:uniform(2),
		    if
			Pick =:= 1 -> goleftright(Sock, Board, X, Y, RunX);
			true -> goupdown(Sock, Board, X, Y, RunY)
		    end
	    end;
	Y =/= BombY ->
	    Leftcell = bomberman:cell(Board, X-1, Y),
	    Rightcell = bomberman:cell(Board, X+1, Y),
	    MoveLeft = not lists:member(Leftcell, Wallrock),
	    MoveRight = not lists:member(Rightcell, Wallrock),
	    if
		MoveLeft ->
		    bomberman:left(Sock);
		MoveRight ->
		    bomberman:right(Sock);
		true ->
		    goupdown(bomb, Sock, Board, X, Y, BombY)
	    end;
	true ->
	    Downcell = bomberman:cell(Board, X, Y+1),
	    Upcell = bomberman:cell(Board, X, Y-1),
	    MoveDown = not lists:member(Downcell, Wallrock),
	    MoveUp = not lists:member(Upcell, Wallrock),
	    if
		MoveUp ->
		    bomberman:up(Sock);
		MoveDown ->
		    bomberman:down(Sock);
		true ->
		    goleftright(bomb, Sock, Board, X, Y, BombX)
	    end
    end,
    wait_for_bomb(Sock, BombX, BombY).

wait_for_bomb(Sock, BombX, BombY) ->
    receive
	{ok, Json} ->
	    {X, Y} = bomberman:coords(Json),
	    Board = bomberman:board(Json),
	    Bombcell = bomberman:cell(Board, BombX, BombY),
	    Player = bomberman:cell(Board, X, Y),
	    if
		Bombcell =:= Player ->
		    run_away_from(Sock, Board, X, Y, BombX, BombY);
		Bombcell =:= <<"Bomb">> ->
		    Radius = bomberman:radius(Json),
		    case find_bomb(Radius+1, Board, X, Y, all) of
			{run, BombX, BombY} ->
			    run_away_from(Sock, Board, X, Y, BombX, BombY);
			{clear, _, _} ->
			    wait_for_bomb(Sock, BombX, BombY)
		    end;
		Bombcell =:= <<"Flame">> ->
		    wait_for_bomb(Sock, BombX, BombY);
		true ->
		    make_move(Sock, Json)
	    end;
	{error, closed} ->
	    gen_tcp:close(Sock)
    end.

main([Port]) ->
    Sock = bomberman:player("localhost", list_to_integer(Port), self()),
    move(Sock).
