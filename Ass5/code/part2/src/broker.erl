-module(broker).
-behaviour(gen_server).
-import (coordinator, [start/1]).
-export([start/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

start() ->
    gen_server:start(?MODULE, [], []).

init([]) ->
    Queue = maps:new(), % #{ Rounds-> {Name, Pl_pid}}
    Ong = [],  
    Longest = 0,
    DrainFlag = false,
    {ok, #{lm=>Longest, q=>Queue, on=>Ong, df=>DrainFlag}}.

handle_call({Name, Rounds}, P_id, State) ->		% queue_up
		Que = maps:get(q, State),
		Found = maps:is_key(Rounds,Que),
		if
		 Found == true ->	%If other player is found
			{Nm, P1_id} = maps:get(Rounds, Que),	%Get player name, id
			Que_rm = maps:remove(Rounds, Que),	% Remove player from Que
			{ok, Cord} = coordinator:start([P1_id,P_id,Rounds,self()]),	% Start coordinator with player_ids
			gen_server:reply(P1_id, {ok, Name, Cord}),
			Ong = maps:get(on, State),
			NOng = lists:append(Ong, [Cord]),
			Changes = #{on=>NOng, q=>Que_rm},
			Upd_state = maps:merge(State, Changes),
			{reply, {ok, Nm, Cord}, Upd_state, infinity}; % {reply, Reply, NewState}
		true ->
			Que_wp = maps:put(Rounds, {Name, P_id}, Que),
			{noreply, maps:put(q, Que_wp, State), infinity}
		end;
handle_call(tell, _F, State) ->		% temporary tell
	{reply, {ok, State}, State};
handle_call(stats, _From, State)->	% statistics
	L = maps:get(lm, State),
	O = maps:get(on, State),
	Q = maps:get(q, State),
	{reply, {ok, L, maps:size(Q), lists:flatlength(O)}, State}.

handle_cast({Pid, Msg, drain}, State) ->	% Drain 
	UpdatedState = maps:put(df, true, State),
    Return = {noreply, UpdatedState},
    io:format("handle_cast: ~p~n", [Return]),
    Return;
handle_cast({C_id, game_over, GL}, State) ->
	PrevBest = maps:get(lm, State),
	L = maps:get(on, State),
	if(GL > PrevBest) ->
		{noreply, State#{lm := GL, on := lists:delete(C_id, L)}};
	true ->
		{noreply, State#{on := lists:delete(C_id, L)}}
	end.

handle_info(_Info, State) ->
    Return = {noreply, State},
    io:format("handle_info: ~p~n", [Return]),
    Return.

terminate(_Reason, _State) ->
    Return = ok,
    io:format("terminate: ~p~n", [Return]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    Return = {ok, State},
    io:format("code_change: ~p~n", [Return]),
    Return.