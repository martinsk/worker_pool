-module(wpool_bench).
-author('elbrujohalcon@inaka.net').

%% External API
-export([run_tasks/3, run_redis/3]).

%%% Internal exports needed for MFA calling
-export([redis_n_times/2, get_uuids/1]).

%% @doc Returns the average time involved in processing the small tasks
-spec run_tasks([{small|large, pos_integer()},...], wpool:strategy(), [wpool:option()]) -> float().
run_tasks(TaskGroups, Strategy, Options) ->
    Tasks = lists:flatten([lists:duplicate(N, Type) || {Type, N} <- TaskGroups]),
    {ok, _Pool} = wpool:start_sup_pool(?MODULE, Options),
    try lists:foldl(
            fun (small, Acc) ->
                    {Time, {ok, 0}} =
                        timer:tc(wpool, call, [?MODULE, {erlang, '+', [0,0]}, Strategy, infinity]),
                    [Time/1000|Acc];
                (large, Acc) ->
                    wpool:cast(?MODULE, {timer, sleep, [30000]}, Strategy),
                    Acc
            end, [], Tasks) of
        [] ->
            lager:warning("No times"),
            0.0;
        Times ->
            ct:log("Times: ~p", [Times]),
            lists:sum(Times) / length(Times)
    after
        wpool:stop_pool(?MODULE)
    end.

%% @doc Returns the transactions per second for simulated redis calls
-spec run_redis(wpool:strategy(), [wpool:option()], string()) -> pos_integer().

run_redis(Strategy, Options, Label) ->
    {ok, _Pool} = wpool:start_sup_pool(redis, Options),
    Num_Transactions = 10000,
    try   {Elapsed, ok} = timer:tc(?MODULE, redis_n_times, [Num_Transactions, Strategy]),
          Time_In_Seconds = Elapsed / 1000000,
          Rate = Num_Transactions / Time_In_Seconds,
          ct:log("Transactions per second using ~s (~p trans): ~p", [Label, Num_Transactions, Rate])
    after wpool:stop_pool(redis)
    end.

%%% A simulated redis call returns 20 random uuids, do it N times.
-spec redis_n_times(non_neg_integer(), wpool:strategy()) -> ok.

redis_n_times(0, _Strategy) -> ok;
redis_n_times(N,  Strategy) ->
    wpool:call(redis, {?MODULE, get_uuids, [20]}, Strategy, 5000),
    redis_n_times(N-1, Strategy).


%%% Simulate fetching uuids from redis to trigger GC occasionally.
-spec get_uuids(pos_integer()) -> [binary()].

get_uuids(N) -> random_uuids(N, []).

random_uuids(0, Ids) -> Ids;
random_uuids(N, Ids) -> random_uuids(N-1, [uuid() | Ids]).

uuid() ->
    list_to_binary([
                    hex_chars( 8), "-",
                    hex_chars( 4), "-",
                    hex_chars( 4), "-",
                    hex_chars( 4), "-",
                    hex_chars(12)
                   ]).

hex_chars(N) -> hex_chars(N, []).

hex_chars(0, Chars) -> Chars;
hex_chars(N, Chars) -> hex_chars(N-1, [hex(random:uniform(16) - 1) | Chars]).

hex( 0) -> $0;
hex( 1) -> $1;
hex( 2) -> $2;
hex( 3) -> $3;
hex( 4) -> $4;
hex( 5) -> $5;
hex( 6) -> $6;
hex( 7) -> $7;
hex( 8) -> $8;
hex( 9) -> $9;
hex(10) -> $A;
hex(11) -> $B;
hex(12) -> $C;
hex(13) -> $D;
hex(14) -> $E;
hex(15) -> $F.
