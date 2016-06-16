-module(wpool_stacktrace_counter).

-export([init/1, increment/1]).

init(Name) ->
    ets:new(Name, [ordered_set, public, named_table]).

increment(Name) ->
    {'EXIT', {_ , Stacktrace}} = (catch 1/0),
    case ets:member(Name, Stacktrace) of
	true -> 
	    ets:update_counter(Name, Stacktrace, 1);
	false ->
	    ets:insert(Name, {Stacktrace, 1})
    end.
	
