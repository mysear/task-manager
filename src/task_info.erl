-module(task_info).
-export([multipart/2, getalltask/0, deltask/1]).

-record(upload, {fd, filename, last, cmd, type, timeout, min, hour, day, month, week}).
-define(DIR, "../www/taskfiles/").

%% 处理解析后的报文，根据报文头分类
multipart(Parse, State)  when State == undefined ->
  NewState = #upload{},
  multipart(Parse, NewState);
multipart({cont, Cont, Res}, State) ->
  io:format("cont args:~p~n", [Res]),
  case classifypack(Res, State) of
    {done, Result} ->
      Result;
    {cont, NewState} ->
      {get_more, Cont, NewState}
  end;
multipart({result, Res}, State) ->
  io:format("result args:~p~n", [Res]),
  case classifypack(Res, State#upload{last=true}) of
    {done, Result} ->
      Result;
    {cont, _} ->
      err()
  end;
multipart({error, _Reason}, _State) ->
  err().

%% 处理报文head和body部分，区分是文件操作还是文本操作
% 1.文件部分报文格式分三种
%   ---{body, Data}
%   ---{head, _}, {part_body, _}
%   ---{head, _}, {body, _}
% 2.文本部分报文格式
%   ---{head, _}, {body, _}
classifypack([{body, Data}|Res], State) ->
  case recvfile({body, Data}, State) of
    ok ->
      io:format("write file content sucessfully.~n"),
      classifypack(Res, State);
    Err ->
      io:format("write file error:~p~n", [Err]),
      {undone, err()}
  end;
classifypack([{head, {Name, Opts}}, {part_body, Data} | Res], State) ->
  classifypack([{head, {Name, Opts}}, {body, Data} | Res], State);
classifypack([{head, {Name, Opts}}, {body, Data} | Res], State) ->
  case lists:keysearch("filename", 1, Opts) of 
    {value, {_, Fname0}} ->
      Fname = yaws_api:sanitize_file_name(basename(Fname0)),
      io:format("Create file: ~p~n", [Fname]),
      file:make_dir(?DIR),
      case file:open([?DIR, Fname] ,[write]) of
        {ok, Fd} ->
          S2 = State#upload{filename = Fname,
                            fd = Fd},
          case recvfile({body, Data}, S2) of
            ok ->
              io:format("write file content sucessfully.~n"),
              classifypack(Res, S2);
            Err ->
              io:format("write file error:~p~n", [Err]),
              {undone, err()}
            end;
        Err ->
          io:format("creaet file error:~p~n", [Err]),
          {undone, err()}
      end;
    false ->
      io:format("not file info, name is ~p, value is ~p.~n", [Name, Data]),
      NewState = handletaskinfo(Name, {body, Data}, State),
      classifypack(Res, NewState)
  end;
classifypack([], State) when State#upload.last==true,
                             State#upload.filename /= undefined,
                             State#upload.fd /= undefined ->
  file:close(State#upload.fd),
  io:format("classify multi part completely~n"),
  io:format("state{fd=~p, filename=~p, last=~p, tasktype=~p}~n",
            [State#upload.fd, State#upload.filename, State#upload.last, State#upload.type]),
  % 处理完所有信息后存储任务，存储当前时间以便进行定时器处理
  tasksave(State),
  Res= {ehtml, {p, [], "finish"}},
  {done, Res};
classifypack([], State) when State#upload.last==true ->
    io:format("No content last is true~n"),
    {done, err()};
classifypack([], State) ->
    io:format("receive more content without last is true~n"),
    {cont, State};
classifypack(_, _State) ->
  {done, err()}.

%% 解析文件名
basename(FilePath) ->
  case string:rchr(FilePath, $\\) of
    0 ->
      %% probably not a DOS name
      filename:basename(FilePath);
    N ->
      %% probably a DOS name, remove everything after last \
      basename(string:substr(FilePath, N+1))
  end.

%% 存储接收到的文件
recvfile({part_body, Data}, State) ->
  recvfile({body, Data}, State);
recvfile({body, Data}, State)  when State#upload.filename /= undefined ->
    file:write(State#upload.fd, Data);
recvfile(_, _State) ->
  err().

%% 处理文本信息
handletaskinfo("task_type", {body, Data}, State) ->
  io:format("task_type value is ~p~n", [Data]),
  NewState = State#upload{type=Data},
  NewState;
handletaskinfo("loop_timer", {body, Data}, State) ->
  io:format("loop_timer value is ~p~n", [Data]),
  NewState = State#upload{timeout=Data},
  NewState;
handletaskinfo("date_min", {body, Data}, State) ->
  io:format("date_min value is ~p~n", [Data]),
  NewState = State#upload{min=Data},
  NewState;
handletaskinfo("date_hour", {body, Data}, State) ->
  io:format("date_hour value is ~p~n", [Data]),
  NewState = State#upload{hour=Data},
  NewState;
handletaskinfo("date_day", {body, Data}, State) ->
  io:format("date_day value is ~p~n", [Data]),
  NewState = State#upload{day=Data},
  NewState;
handletaskinfo("date_month", {body, Data}, State) ->
  io:format("date_month value is ~p~n", [Data]),
  NewState = State#upload{month=Data},
  NewState;
handletaskinfo("date_week", {body, Data}, State) ->
  io:format("date_week value is ~p~n", [Data]),
  NewState = State#upload{week=Data},
  NewState;
handletaskinfo(UnExpect, {body, Data}, State) ->
  io:format("Unknow type: ~p, value is ~p~n", [UnExpect, Data]),
  State;
handletaskinfo(UnExpect, Data, State) ->
  io:format("Unknow type: ~p and error value is ~p~n", [UnExpect, Data]),
  State.


tasksave(State) when State#upload.type == "loop" ->
  io:format("Save loop task~n"),
  if State#upload.timeout /= undefined ->
      TimeStamp = os:timestamp(),
      io:format("time is ~p~n", [calendar:now_to_local_time(TimeStamp)]),
      db_api:add_task(State#upload.filename, State#upload.type, State#upload.timeout, State#upload.cmd, TimeStamp);
    true-> io:format("not set timeout~n")
  end;
tasksave(State) when State#upload.type == "date" ->
  io:format("Save date task~n"),
  if State#upload.min /= undefined, State#upload.hour /= undefined, State#upload.day /= undefined,
     State#upload.month /= undefined, State#upload.week /= undefined ->
       io:format("Timeout for date task is ok~n"),
       DateTimeout = string:join([State#upload.min, State#upload.hour, State#upload.day,
                                  State#upload.month, State#upload.week], ";"),
       TimeStamp = os:timestamp(),
       io:format("Now is ~p, Date timeout is ~p~n", [calendar:now_to_local_time(TimeStamp), DateTimeout]),
       db_api:add_task(State#upload.filename, State#upload.type, DateTimeout, State#upload.cmd, TimeStamp);
    true->io:format("error date timeout~n")
  end;
tasksave(State) ->
  io:format("Error state--fd:~p filename:~p last:~p cmd:~p, type:~p timeout:~p min:~p hour:~p day:~p month:~p, week:~p~n",
            [State#upload.fd, State#upload.filename, State#upload.last, State#upload.cmd, State#upload.type, State#upload.timeout,
             State#upload.min, State#upload.hour, State#upload.day, State#upload.month, State#upload.week]),
  ok.

%% 设置error信息
err() ->
  {ehtml, {p, [], "error"}}.

getalltask()->
%  {_TblName, TaskName, TaskType, Timeout, Cmd, LocalTime}
  TblContent = db_api:get_all_task(),
  io:format("All task info:~p~n", [TblContent]),
  encodeTaskInfo(TblContent, []).

encodeTaskInfo([{task, Name, _Type, Timeout, Cmd, _LocalTime} | Res], Result) ->
  NewResult = [{struct, [{name, Name}, {timeout, Timeout}, {cmd, Cmd}]} | Result],
  encodeTaskInfo(Res, NewResult);
encodeTaskInfo([], Result) ->
  {array, Result}.

deltask([{"value[]", TaskName} | Res]) ->
  io:format("Delete task:~p~n", [TaskName]),
  db_api:del_task(TaskName),
  FilePath=string:concat(?DIR, TaskName),
  file:delete(FilePath),
  deltask(Res);
deltask([]) ->
  io:format("All tasks have been deleted.~n"),
  ok;
deltask(Unexpected) ->
  io:format("Unexpected info:~p~n", [Unexpected]).
