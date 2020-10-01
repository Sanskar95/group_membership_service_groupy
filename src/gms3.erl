
-module(gms3).

-define(timeout, 200).
-define(arghh, 100).
-define(messageLoosingMetric, 50).
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
            erlang:monitor(process, Leader),
            Master ! {view, Group},
            slave(Id, Master, Leader, N+1, {view, N, [Leader|Slaves], Group}, Slaves, Group)
    after ? timeout ->
        Master ! {error, "no reply from leader"}
    end.

leader(Id, Master, N, Slaves, Group) ->
    receive
        {mcast, Msg} ->
%%            io:format("gms 3 ~w: received the message  {mcast, ~w} ~n", [Id, Msg]),
            bcast(Id, {msg, N, Msg}, Slaves),
            Master ! Msg,
            leader(Id, Master, N+1, Slaves, Group);
        {join, Wrk, Peer} ->
%%            io:format("gms 3 ~w: redirect  join request  from ~w to app layer(master)~n", [Id, Peer]),
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
        {'DOWN', _Ref, process, Leader, Reason} ->
%%            io:format("Leader process has crashed ~w~n", [Reason]),
            election(Id, Master, N, Last, Slaves, Group);
        {mcast, Msg} ->
%%            io:format("gms 3 ~w: received the message {mcast, ~w} ~n", [Id, Msg]),
            Leader ! {mcast, Msg},
            slave(Id, Master, Leader, N, Last, Slaves, Group);
        {join, Wrk, Peer} ->
%%            io:format("gms 3 ~w: forwarding join request  from the node ~w to leader~n", [Id, Peer]),
            Leader ! {join, Wrk, Peer},
            slave(Id, Master, Leader, N, Last, Slaves, Group);
        {msg, I, _} when I < N ->
%%            io:format("gms 3 : recieved  msg with sequence  ~w ~n", [N]),
            slave(Id, Master, Leader, N, Last, Slaves, Group);
        {msg, N, Msg} ->
%%            io:format("gms 3 ~w: recieved join confirmation msg, sequence ~w ~w ~n", [Id, Msg, N]),
            bcast(Id, {msg, N, Msg}, Slaves),
            Master ! Msg,
            slave(Id, Master, Leader, N+1, {msg, N, Msg}, Slaves, Group);
        {view, N, [Leader|Slaves2], Group2} ->
            bcast(Id, {view, N,[Leader|Slaves2], Group2}, Slaves),
            Master ! {view, Group2},
            slave(Id, Master, Leader, N+1, {view, N, [Leader|Slaves2], Group2}, Slaves2, Group2);
        stop ->
            ok

    end.


election(Id, Master, N, Last, Slaves, [_|Group]) ->
    io:format("Last message: ~w~n", [Last]),
    Self = self(),
    case Slaves of
        [Self|Rest] ->
            bcast(Id, Last, Rest),
            bcast(Id, {view, N, Slaves, Group}, Rest),
            Master ! {view, Group},
            io:format("Your new Leader is: ~w~n", [Self]),
            io:format("Your new Leader_Id is: ~w~n", [Id]),
            leader(Id, Master, N+1, Rest, Group);
        [Leader|Rest] ->
            erlang:monitor(process, Leader),
            slave(Id, Master, Leader, N, Last, Rest, Group)
    end.

bcast(Id, Msg, Nodes) ->
    lists:foreach(fun(Node) -> forcedLostMessage(Id,Msg,Node)  end, Nodes).

forcedLostMessage(Id, Msg,Node)->
    %% Decide if a message will be lost
    case random:uniform(?messageLoosingMetric) of
        ?messageLoosingMetric ->
           %%Simulating a lost message using message loosing metric
            io:format("Message ~w was lost ~n", [Msg]),
            timer:sleep(100),
            %% try the method again recursively hoping to send the message again :)
            io:format(" Resending Message ~w that was lost ~n", [Msg]),
            forcedLostMessage(Id, Msg,Node);
        _ ->
            %% Send a message normally
            Node ! Msg
    end.


crash(Id) ->
    timer:sleep(500),
    case random:uniform(?arghh) of
        ?arghh ->
            io:format("leader ~w: has crashed ~n", [Id]),
            exit(no_luck);
        _ ->
            ok
    end.