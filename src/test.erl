-module(test).

-compile(export_all).

start(Module) ->
  worker:start(0, l, Module, 1000),
  timer:sleep(100),
  List=[w0,w1,w2,w3,w4],
  lists:foldl(fun(Name, Acc) -> worker:start(Acc, Name, Module, l, 1000), Acc+1 end, 1, List).


first(N, Name, Module, Sleep) ->
   worker:start(N,Name, Module, random:uniform(256), Sleep).

% Used to create additional workers, try:
%
%  test:add(2, gms1, W1, 1000) and 
%  test:add(3, gms1, W1, 1000) and ...

add(N, Name, Module, Wrk, Sleep) ->
   worker:start(N, Name, Module, random:uniform(256), Wrk, Sleep).

%% To create a number of workers in one go, 
%%
%%more(N, Module, Sleep) when N > 1 ->
%%    Wrk = first(1, Module, Sleep),
%%    Ns = lists:seq(2,N),
%%    lists:map(fun(Id) -> add(Id, Module, Wrk, Sleep) end, Ns),
%%    Wrk.
%%

% These are messages that we can send to one of the workers. It will
% multicast it to all workers. They should (if everything works)
% receive the message at the same (logical) time.

freeze(Wrk) ->
    Wrk ! {send, freeze}.

go(Wrk) ->
    Wrk ! {send, go}.

sleep(Wrk, Sleep) ->
    Wrk ! {send, {sleep, Sleep}}.



			  

















