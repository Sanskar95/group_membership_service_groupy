-module(gms2).
-export([start/1, start/2]).

-define(timeout, 300).
-define(arghh, 200).

start(Id) ->
    Rnd = random:uniform(1000),
    Self = self(),
    {ok, spawn_link(fun()-> init(Id,Rnd, Self) end)}.

init(Id, Rnd, Master) ->
    random:seed(Rnd, Rnd, Rnd),
    leader(Id, Master, [], [Master]).

start(Id, Grp) ->
    Rnd = random:uniform(1000),
    Self = self(),
    {ok, spawn_link(fun()-> init(Id, Rnd, Grp, Self) end)}.

init(Id,Rnd, Grp, Master) ->
    random:seed(Rnd, Rnd, Rnd),
    Self = self(),
    Grp ! {join, Master, Self},
    receive
        {view, [Leader|Slaves], Group} ->
            Master ! {view, Group},
            slave(Id, Master, Leader, Slaves, Group)
    after ? timeout ->
        Master ! {error, "no reply from leader"}
    end.


slave(Id, Master, Leader, Slaves, Group) ->
    receive
        {mcast, Msg} ->
            io:format("gms 2 ~w: received the message {mcast, ~w} ~n", [Id, Msg]),
            Leader ! {mcast, Msg},
            slave(Id, Master, Leader, Slaves, Group);
        {join, Wrk, Peer} ->
            io:format("gms 2 ~w: forwarding join request  from the node ~w to leader~n", [Id, Peer]),
            Leader ! {join, Wrk, Peer},
            slave(Id, Master, Leader, Slaves, Group);
        {msg, Msg} ->
            io:format("gms 2 ~w: recieved join confirmation msg ~w ~n", [Id, Msg]),
            Master ! Msg,
            slave(Id, Master, Leader, Slaves, Group);
        {view, [Leader | Slaves2], Group2} ->
            Master ! {view, Group2},
            slave(Id, Master, Leader, Slaves2, Group2);
        {'DOWN', _Ref, process, Leader, Reason} ->
            election(Id, Master, Slaves, Group),
            io:format("Leader process has crashed ~w~n", [Reason]);
        stop ->
            ok;
        _ ->
            io:format("gms 2 : slave, Error message ~w~n", [Id])
    end.

election(Id, Master, Slaves, [_ | Group]) ->
    Self = self(),
    case Slaves of
        [Self | Rest] ->
            bcast(Id, {view, Slaves, Group}, Rest),
            Master ! {view, Group},
            io:format("Your new Leader is: ~w~n", [Self]),
            io:format("Your new Leader_Id is: ~w~n", [Id]),
            leader(Id, Master, Rest, Group);
        [Leader | Rest] ->
            erlang:monitor(process, Leader),
            io:format("Your new Leader is ~w~n", [Leader]),
            slave(Id, Master, Leader, Rest, Group)
    end.

leader(Id, Master, Slaves, Group) ->
    receive
        {mcast, Msg} ->
            io:format("gms 2 ~w: received the message  {mcast, ~w} ~n", [Id, Msg]),
            bcast(Id, {msg, Msg}, Slaves),
            Master ! Msg,
            leader(Id, Master, Slaves, Group);
        {join, Wrk, Peer} ->
            io:format("gms 2 ~w: redirect  join request  from ~w to app layer(master)~n", [Id, Peer]),
            Slaves2 = lists:append(Slaves, [Peer]),
            Group2 = lists:append(Group, [Wrk]),
            bcast(Id, {view, [self() | Slaves2], Group2}, Slaves2),
            Master ! {view, Group2},
            leader(Id, Master, Slaves2, Group2);
        stop ->
            ok;
        _ ->
            io:format("gms 2 : Leader: something went wrong with the reason: ~w~n", [Id])
    end.

bcast(Id, Msg, Nodes) ->
    lists:foreach(fun(Node) -> Node ! Msg, crash(Id) end, Nodes).

crash(Id) ->
    case random:uniform(?arghh) of
        ?arghh ->
            io:format("leader ~w: crash~n", [Id]),
            exit(its_a_crashed_leader);
        _ ->
            ok
    end.
