-module(deploy).

-export([run/0, run_backup/0]).

run() ->
	Symbol = db_backup:get_symbol_sec(),
	db:start(),
	db:backup(Symbol),   % backup data
	db:uninstall(),  % uninstall db to create master and backup db
	db:install(),    % create master and backup db
	db:restore(Symbol).    % restore data

run_backup() ->
	Symbol = db_backup:get_symbol_sec(),
	db:start(),
	db:backup(Symbol),   % backup data
	db:uninstall(backup),  % uninstall db to create master and backup db
	db:install(backup),    % create master and backup db
	db:restore(backup, Symbol).    % restore data






			


	









