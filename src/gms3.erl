%%%-------------------------------------------------------------------
%%% @author Amir
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 01. okt 2016 16:00
%%%-------------------------------------------------------------------
-module(gms3).

%% API
-define(timeout, 2000).
-define(arghh, 200).
-define(chanceOfLosing, 25).
-compile(export_all).

start(Id) ->
    Rnd = random:uniform(1000),
    Self = self(),
    {ok, spawn_link(fun()-> init(Id,Rnd, Self) end)}.

init(Id, Rnd, Master) ->
    random:seed(Rnd, Rnd, Rnd),
    leader(Id, Master, 0, [], [Master]).

start(Id, Grp) ->
    Rnd = random:uniform(1000),
    Self = self(),
    {ok, spawn_link(fun()-> init(Id, Rnd, Grp, Self) end)}.

init(Id,Rnd, Grp, Master) ->
    random:seed(Rnd, Rnd, Rnd),
    Self = self(),
    Grp ! {join, Master, Self},
    receive
        {view, N, [Leader|Slaves], Group} ->
            % erlang:display("Kommer jag in i receive i init"), erlang:display(self()),
            erlang:monitor(process, Leader),
            Master ! {view, Group},
            slave(Id, Master, Leader, N+1, {view, N, [Leader|Slaves], Group}, Slaves, Group)
    after ? timeout ->
        Master ! {error, "no reply from leader"}
    end.

leader(Id, Master, N, Slaves, Group) ->
    receive
        {mcast, Msg} ->
            bcast(Id, {msg, N, Msg}, Slaves),
            Master ! Msg,
            leader(Id, Master, N+1, Slaves, Group);
        {join, Wrk, Peer} ->
            %erlang:display("Kommer jag in i leader funktionen nar jag ska joina en slav"), erlang:display(self()),
            Slaves2 = lists:append(Slaves, [Peer]),
            Group2 = lists:append(Group, [Wrk]),
            bcast(Id, {view, N, [self()|Slaves2], Group2}, Slaves2),
            Master ! {view, Group2},
            leader(Id, Master, N+1, Slaves2, Group2);
        stop ->
            ok
    end.

slave(Id, Master, Leader, N, Last, Slaves, Group) ->
    receive
        {'DOWN', _Ref, process, Leader, _Reason} ->
            election(Id, Master, N, Last, Slaves, Group);
        {mcast, Msg} ->
            %erlang:display("Kommer jag in som slav i mcast"), erlang:display(self()),
            Leader ! {mcast, Msg},
            slave(Id, Master, Leader, N, Last, Slaves, Group);
        {join, Wrk, Peer} ->
            Leader ! {join, Wrk, Peer},
            slave(Id, Master, Leader, N, Last, Slaves, Group);
        {msg, I, _} when I < N ->
            slave(Id, Master, Leader, N, Last, Slaves, Group);
        {msg, N, Msg} ->
            bcast(Id, {msg, N, Msg}, Slaves),
            Master ! Msg,
            slave(Id, Master, Leader, N+1, {msg, N, Msg}, Slaves, Group);
        {view, N, [Leader|Slaves2], Group2} ->
            %erlang:display("Mitt N är med den här worker"), erlang:display(N), erlang:display(self()),
            bcast(Id, {view, N,[Leader|Slaves2], Group2}, Slaves),
            Master ! {view, Group2},
            slave(Id, Master, Leader, N+1, {view, N, [Leader|Slaves2], Group2}, Slaves2, Group2);
        stop ->
            ok

    end.


election(Id, Master, N, Last, Slaves, [_|Group]) ->
    erlang:display("Kommer in i election med ID"), erlang:display(self()),
    Self = self(),
    case Slaves of
        [Self|Rest] ->
            bcast(Id, Last, Rest),
            bcast(Id, {view, N, Slaves, Group}, Rest),
            Master ! {view, Group},
            leader(Id, Master, N+1, Rest, Group);
        [Leader|Rest] ->
            %io:format("Jag ar och followar , ~w  ~w", [self(),Leader]),
            erlang:monitor(process, Leader),
            slave(Id, Master, Leader, N, Last, Rest, Group)
    end.

bcast(Id, Msg, Nodes) ->

    %case random:uniform(?chanceOfLosing) of
    %?chanceOfLosing -> lostMessage(Msg);
    %_ ->
    lists:foreach(fun(Node) -> forcedLostMessage(Id,Msg,Node), crash(Id)  end, Nodes).
% end.

%lostMessage(Msg)->
%      io:format("Did not send message, ~w", [Msg]).

forcedLostMessage(Id, Msg,Node)->
    case random:uniform(?chanceOfLosing) of
        ?chanceOfLosing -> ok, io:format("Message ~w was lost ~n", [Msg]);
        _ -> Node ! Msg
    end.

crash(Id) ->
    case random:uniform(?arghh) of
        ?arghh ->
            io:format("leader ~w: crash~n", [Id]),
            exit(no_luck);
        _ ->
            ok
    end.