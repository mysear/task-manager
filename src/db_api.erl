-module(db_api).

-include_lib("stdlib/include/qlc.hrl").
-include("db_table.hrl").

-export([add_task/5, del_task/1, get_all_task/0, get_task/1]).

add_task(Name, Type, Timeout, Cmd, TimeStamp) ->
  	F = fun() ->
        mnesia:write(#task{name=Name, type=Type, timeout=Timeout, cmd=Cmd, timestamp=TimeStamp})
    end,
    mnesia:transaction(F).

del_task(Name) ->
    F = fun() ->
        mnesia:delete({task, Name})
    end,
    mnesia:transaction(F).

get_task(Name) ->
    do_qeury(qlc:q([X || X <- mnesia:table(task), X#task.name =:= Name])).

get_all_task() ->
    do_qeury(qlc:q([X || X <- mnesia:table(task)])).

do_qeury(Query) ->
	F = fun() -> qlc:e(Query) end,
	{atomic, Val} = mnesia:transaction(F),
	Val.


