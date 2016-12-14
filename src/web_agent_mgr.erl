-module(web_agent_mgr).
-behavior(gen_server).

-include("yaws_api.hrl").

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export([start_link/0]).

-record(state, {agents = [], index = 1}).
-define(TIMER_LOOP, 60*1000).

%% User API
start_link() ->
  deploy:run(),
  {ok, Pid} = gen_server:start_link({local, ?MODULE}, ?MODULE, [], []),
  {ok, Pid}.


exec_task([{task, TaskPath, "loop", Timeout, Cmd, {TMegaSecs, TSecs, _}} | Res], {MegaSecs, Secs, MicorSecs}) ->
%需要增加任务是否达到定时时间的判断
  io:format("execute loop task.~n"),
  Step = ((MegaSecs - TMegaSecs)*1000000 + Secs - TSecs) div 60,
  Timer = erlang:list_to_integer(Timeout),
  io:format("Time step is ~p, timeout is ~p~n", [Step, Timer]),
  if Step rem Timer =:= 0 ->
    {ok, Pid} = task_exec:start(TaskPath, Cmd),
    erlang:monitor(process, Pid);
    true -> ok
  end,
  exec_task(Res, {MegaSecs, Secs, MicorSecs});
exec_task([{task, TaskPath, "date", Timeout, Cmd, _TimeStamp} | Res], Now) ->
  io:format("execute date task.~n"),
  case cmpdatetime(Timeout, Now) of
    true ->
      {ok, Pid} = task_exec:start(TaskPath, Cmd),
      erlang:monitor(process, Pid),
      exec_task(Res, Now);
    false -> exec_task(Res, Now)
  end;
exec_task([], _Now)->
  ok.

% 比较当前时间和设定时间是否一致
cmpdatetime(DateTimeout, Now) ->
  io:format("time is ~p, now is ~p~n", [DateTimeout, calendar:now_to_local_time(Now)]),
  [Min, Hour, Day, Month, Week] = string:tokens(DateTimeout, ";"),
  {IntMin, _} = string:to_integer(Min),
  {IntHour, _} = string:to_integer(Hour),
  {IntDay, _} = string:to_integer(Day),
  {IntMonth, _} = string:to_integer(Month),
  {IntWeek, _} = string:to_integer(Week),

  {{NYear, NMonth, NDay}, {NHour, NMin, _}} = calendar:now_to_local_time(Now),
  NWeek = calendar:day_of_the_week(NYear, NMonth, NDay),
  if Min /= "*", IntMin /= NMin -> false;
     Hour /= "*", IntHour /= NHour -> false;
     Day /= "*", IntDay /= NDay -> false;
     Month /= "*", IntMonth /= NMonth -> false;
     Week /= "*", IntWeek /= NWeek -> false;
  true -> true
end.

%% gen_server API. User realize his own function.
init([]) ->
  timer:send_interval(?TIMER_LOOP, self(), loop_interval_event),
  {ok, #state{}}.

handle_info(loop_interval_event, State) ->
  io:format("Receive timer report in handle_info~n"),
  TblContent = db_api:get_all_task(),
  io:format("Table info:~p~n", [TblContent]),
  TimeStamp = os:timestamp(),
  io:format("time is ~p~n", [calendar:now_to_local_time(TimeStamp)]),
  exec_task(TblContent, TimeStamp),
  {noreply, State};
handle_info({'DOWN', _, process, Pid, Reason}, State) ->
  error_logger:format("task ~p down, reason ~p~n", [Pid, Reason]),
  {noreply, State}.

handle_cast(_, State) ->
  {noreply, State}.

handle_call(_, _From, State) ->
  {reply, [], State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.