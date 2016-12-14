-module(ybed_sup).
-behavior(supervisor).
-export([start_link/0]).
-export([init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
  MaxRestart = 10,
  MaxTime = 3600,
  WebAgent = {web_agent_mgr, {web_agent_mgr, start_link, []},
             permanent, 5000, worker, [web_agent_mgr]},
  YBed = {ybed, {ybed, start, []},
             permanent, 2000, worker, [ybed]},
  {ok, {{one_for_one, MaxRestart, MaxTime}, [YBed, WebAgent]}}.