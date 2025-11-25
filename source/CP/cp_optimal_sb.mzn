include "global_cardinality.mzn";
include "alldifferent.mzn";
include "global_cardinality.mzn";

% =====================
% Parameters
% =====================

int: n; 
set of int: Teams = 1..n;
set of int: Weeks = 1..(n-1);
set of int: Periods = 1..(n div 2);

% =====================
% Decision Variables
% =====================

% match[w,p,1] = home team, match[w,p,2] = away team
array[Weeks, Periods, 1..2] of var Teams: match;

% =====================
% Constraints
% =====================


% 1. each team plays exactly once per week
constraint forall(w in Weeks)(
    global_cardinality([match[w,p,s] | p in Periods, s in 1..2],
                       [t | t in Teams],
                       [1 | t in Teams]) 
);

% 2. each team plays at most twice in the same period
constraint forall(p in Periods, t in Teams) (
    sum(w in Weeks)(bool2int(match[w,p,1] = t) + bool2int(match[w,p,2] = t)) <= 2
);

% 3. each pair of teams plays exactly once (using alldifferent)
constraint forall(a in Teams, b in Teams where a < b) (
  sum(w in Weeks, p in Periods)(
    bool2int(match[w,p,1] = a /\ match[w,p,2] = b) +
    bool2int(match[w,p,1] = b /\ match[w,p,2] = a)
  ) = 1
);

% =========================
% Symmetry Breaking
% =========================

% Fix the first week
constraint forall(p in Periods)(
    match[1,p,1] = 2*p - 1 /\ match[1,p,2] = 2*p
);

% Lexicographic ordering between consecutive weeks
constraint forall(w in 1..(n-2)) (
    lex_less([match[w,p,s] | p in Periods, s in 1..2],
             [match[w+1,p,s] | p in Periods, s in 1..2])
);

% =====================
% Optimization: balance home/away fairness
% =====================

% get the count of home games
array[Teams] of var 0..(n-1): home_games;
constraint global_cardinality(
    [ match[w,p,1] | w in Weeks, p in Periods ], 
    Teams,
    home_games
);

% calculate the deviation between home and away, then minimize
var int: max_dev;
constraint max_dev = max(t in Teams)(
    abs(2 * home_games[t] - (n - 1))
);

% =====================
% Solve 
% =====================

int: use_ss;

solve :: 
    if use_ss == 1 then
        int_search(
            match,
            dom_w_deg,       
            indomain_random 
        )
        :: restart_geometric(1.5, 500) 
    endif
    minimize max_dev;

% =====================
% Output
% =====================

output [
  "{\n"++
  " \"optimal\": " ++ (if show(max_dev==1)=="true" then "True" else "False" endif) ++ ",\n" ++
  " \"obj\":"++show(max_dev)++" ,\n" ++
  " \"sol\": [\n" ++
  concat([
    "  [" ++ concat([
        "[" ++ show(match[w,p,1]) ++ "," ++ show(match[w,p,2]) ++ "]"
        ++ ( if w < max(Weeks) then "," else "" endif )
      | w in Weeks]) ++ "]"
    ++ ( if p < max(Periods) then ",\n" else "\n" endif )
  | p in Periods]) ++
  " ]\n" ++
  "}\n"
];
