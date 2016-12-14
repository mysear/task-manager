-module(task_exec).

-export([start/2, run/2]).

start(TaskPath, Cmd) ->
  P = spawn(fun() -> run(TaskPath, Cmd) end),
  {ok, P}.

run(TaskPath, Cmd) ->
  io:format("taskpath=~p, Cmd=~p~n", [TaskPath, Cmd]),
  hello().

hello() ->
  io:format("Call python to start work.~n"),
  os:cmd("echo hello world").

my_exec(Command) ->
    Port = open_port({spawn, Command}, [stream, in, eof, hide, exit_status]),
    Result = get_data(Port, []),
    Result.
get_data(Port, Sofar) ->
    receive
    {Port, {data, Bytes}} ->
        get_data(Port, [Sofar|Bytes]);
    {Port, eof} ->
        Port ! {self(), close},
        receive
        {Port, closed} ->
            true
        end,
        receive
        {'EXIT',  Port,  _} ->
            ok
        after 1 ->              % force context switch
            ok
        end,
        ExitCode =
            receive
            {Port, {exit_status, Code}} ->
                Code
        end,
        {ExitCode, lists:flatten(Sofar)}
    end.