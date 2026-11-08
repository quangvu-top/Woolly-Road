class_name Levels
extends RefCounted
## The 50 levels. Pens bottom(exit) -> top(entry); queues front-first; cap = road slots (5 everywhere).
## Colours: P pink, B blue, Y yellow, L lavender, O orange, W white, K charcoal. Each verified solvable by the tests;
## p = win chance under random taps: level 1 (tutorial) 100%, then hard levels 9.6% -> 0.6%; levels 2-50 come
## from tests/gen_levels.gd (traps = wrong taps on the winning line that make the level unwinnable).

const ALL := [
	{lanes = ["YPPP", "YBBB"], queues = ["BY", "PY"], cap = 5, tutorial = true},                # p = 1.00
	{lanes = ["OLOY", "BWWB", ""], queues = ["YPOWBW", "LYOPB", "PPLYL"], cap = 5, hard = true},  # 2: p = 0.096, traps 2, nodes 590
	{lanes = ["PBLY", "YPL", ""], queues = ["POOYL", "LOYB", "BOBP"], cap = 5, hard = true},  # 3: p = 0.059, traps 2, nodes 469
	{lanes = ["LOBP", "BPY", ""], queues = ["BOPOY", "YLLO", "BPLY"], cap = 5, hard = true},  # 4: p = 0.057, traps 2, nodes 288
	{lanes = ["OLLB", "BBO", ""], queues = ["YYPLO", "LPPY", "BPYO"], cap = 5, hard = true},  # 5: p = 0.051, traps 2, nodes 457
	{lanes = ["YOOW", "BPWY", ""], queues = ["BOLOWB", "LLYPY", "LPWPB"], cap = 5, hard = true},  # 6: p = 0.039, traps 2, nodes 524
	{lanes = ["YBBP", "LOO", ""], queues = ["PWWBYL", "YPWWBO", "LYOPL"], cap = 5, hard = true},  # 7: p = 0.036, traps 2, nodes 808
	{lanes = ["BPLY", "PYBL", ""], queues = ["BOYP", "PLOY", "OLBO"], cap = 5, hard = true},  # 8: p = 0.032, traps 2, nodes 428
	{lanes = ["OBOY", "WWBL", ""], queues = ["PLPOWY", "WBBLP", "LOPYY"], cap = 5, hard = true},  # 9: p = 0.031, traps 2, nodes 610
	{lanes = ["PWLY", "OBB", ""], queues = ["YLYLPB", "PWOOWL", "OYWBP"], cap = 5, hard = true},  # 10: p = 0.030, traps 2, nodes 616
	{lanes = ["WBOP", "YOL", ""], queues = ["PBOWWY", "YBPLBL", "WOPYL"], cap = 5, hard = true},  # 11: p = 0.028, traps 2, nodes 669
	{lanes = ["YLPB", "PBO", ""], queues = ["OYBOWP", "WWOLBY", "LYLPW"], cap = 5, hard = true},  # 12: p = 0.027, traps 2, nodes 1049
	{lanes = ["WPPL", "WBWO", ""], queues = ["BLLPYO", "WBOBY", "YLOYP"], cap = 5, hard = true},  # 13: p = 0.027, traps 2, nodes 692
	{lanes = ["WPYL", "PBY", ""], queues = ["BYOOOL", "OWBYLB", "WPWPL"], cap = 5, hard = true},  # 14: p = 0.026, traps 2, nodes 1029
	{lanes = ["YYOL", "PWB", ""], queues = ["YPLPWB", "PBOYBL", "WLOWO"], cap = 5, hard = true},  # 15: p = 0.023, traps 2, nodes 834
	{lanes = ["WYOW", "WYO", ""], queues = ["PBPLLB", "YPBYOB", "LOPLW"], cap = 5, hard = true},  # 16: p = 0.021, traps 2, nodes 924
	{lanes = ["BPWO", "PBOB", ""], queues = ["WLOPLL", "YWOYL", "YWPYB"], cap = 5, hard = true},  # 17: p = 0.020, traps 8, nodes 358
	{lanes = ["YOWO", "YBPL", ""], queues = ["LWYPPL", "BYWBO", "WBLOP"], cap = 5, hard = true},  # 18: p = 0.020, traps 3, nodes 509
	{lanes = ["YPLB", "PLL", ""], queues = ["OPBWPY", "BYBOYW", "WOOLW"], cap = 5, hard = true},  # 19: p = 0.020, traps 2, nodes 1039
	{lanes = ["YBLO", "LLBW", ""], queues = ["WLPBWO", "OYPWO", "PBYYP"], cap = 5, hard = true},  # 20: p = 0.017, traps 2, nodes 608
	{lanes = ["PPPW", "YBBO", ""], queues = ["BWOWLY", "OPYWL", "LLBOY"], cap = 5, hard = true},  # 21: p = 0.016, traps 3, nodes 698
	{lanes = ["OWYY", "BBPP", ""], queues = ["LYBOPL", "POLYW", "WLWBO"], cap = 5, hard = true},  # 22: p = 0.016, traps 4, nodes 823
	{lanes = ["YBLP", "LOB", ""], queues = ["WPWPBP", "LYBLYW", "OYOOW"], cap = 5, hard = true},  # 23: p = 0.016, traps 2, nodes 864
	{lanes = ["BOOW", "LWWL", ""], queues = ["OYPYLW", "YBYPO", "BBPPL"], cap = 5, hard = true},  # 24: p = 0.014, traps 4, nodes 680
	{lanes = ["LOPO", "BLYW", ""], queues = ["BOPLOP", "LYYBW", "YBWWP"], cap = 5, hard = true},  # 25: p = 0.013, traps 6, nodes 707
	{lanes = ["WBBY", "BLLW", ""], queues = ["POOYBY", "LOPYW", "WOPPL"], cap = 5, hard = true},  # 26: p = 0.013, traps 2, nodes 542
	{lanes = ["BBLY", "YOP", ""], queues = ["OWWOWP", "PYBPLB", "LOWYL"], cap = 5, hard = true},  # 27: p = 0.013, traps 2, nodes 652
	{lanes = ["BYOW", "WBOL", ""], queues = ["YWOLPB", "BOPYW", "YPLLP"], cap = 5, hard = true},  # 28: p = 0.012, traps 2, nodes 424
	{lanes = ["LYOW", "PBPY", ""], queues = ["WOWPYO", "BLPLY", "WBOLB"], cap = 5, hard = true},  # 29: p = 0.012, traps 7, nodes 787
	{lanes = ["PWYL", "LWO", ""], queues = ["YYBBWP", "WLLOYB", "BPOPO"], cap = 5, hard = true},  # 30: p = 0.012, traps 2, nodes 859
	{lanes = ["BWBL", "WOYP", ""], queues = ["WWOLYP", "YLYBP", "OLBOP"], cap = 5, hard = true},  # 31: p = 0.011, traps 2, nodes 660
	{lanes = ["BLWP", "BYO", ""], queues = ["WYLBWP", "OWOLYY", "PLBPO"], cap = 5, hard = true},  # 32: p = 0.011, traps 2, nodes 464
	{lanes = ["OBPL", "PLYW", ""], queues = ["PYLOWO", "BOWYP", "LBWBY"], cap = 5, hard = true},  # 33: p = 0.011, traps 3, nodes 583
	{lanes = ["YBWY", "WLBO", ""], queues = ["YWOOYB", "PWLPL", "LPPBO"], cap = 5, hard = true},  # 34: p = 0.010, traps 2, nodes 713
	{lanes = ["LWYP", "BBBW", ""], queues = ["OLOOLP", "YPLYO", "YWBPW"], cap = 5, hard = true},  # 35: p = 0.010, traps 7, nodes 384
	{lanes = ["OWYB", "PWL", ""], queues = ["YBLOBL", "PPYWBY", "OPWLO"], cap = 5, hard = true},  # 36: p = 0.010, traps 4, nodes 696
	{lanes = ["YBLY", "WPP", ""], queues = ["OOOYWP", "LBLPBW", "WBYLO"], cap = 5, hard = true},  # 37: p = 0.010, traps 7, nodes 701
	{lanes = ["YPLP", "OWPB", ""], queues = ["LYYBOB", "PLWBW", "OYWOL"], cap = 5, hard = true},  # 38: p = 0.010, traps 2, nodes 586
	{lanes = ["BLWW", "BPB", ""], queues = ["OPLLYY", "YPOOWB", "LPWOY"], cap = 5, hard = true},  # 39: p = 0.010, traps 8, nodes 810
	{lanes = ["BLWL", "LBW", ""], queues = ["WPYOYY", "OPBPLO", "BYWOP"], cap = 5, hard = true},  # 40: p = 0.010, traps 3, nodes 669
	{lanes = ["YWPB", "YKKP", ""], queues = ["BYWWLOB", "LKLBOKP", "WYPOOL"], cap = 5, hard = true},  # 41: p = 0.009, traps 2, nodes 805
	{lanes = ["BOYO", "WBPY", ""], queues = ["PBWLWP", "WYYOL", "LBOPL"], cap = 5, hard = true},  # 42: p = 0.009, traps 7, nodes 547
	{lanes = ["OOPB", "PBL", ""], queues = ["OYLWBW", "PWOYPY", "LBWYL"], cap = 5, hard = true},  # 43: p = 0.009, traps 8, nodes 527
	{lanes = ["WWWK", "BKBO", ""], queues = ["LLKPYYB", "PKLLPBY", "YOPOOW"], cap = 5, hard = true},  # 44: p = 0.008, traps 2, nodes 1051
	{lanes = ["OWBK", "YWPL", ""], queues = ["YOOYPBB", "LOLBKPW", "WKYKPL"], cap = 5, hard = true},  # 45: p = 0.008, traps 4, nodes 483
	{lanes = ["YWBL", "LPOB", "YPW", ""], queues = ["POLWKK", "OKLYWB", "OYBKP"], cap = 5, hard = true},  # 46: p = 0.008, traps 4, nodes 544
	{lanes = ["BKLB", "PYPW", ""], queues = ["LWBBYLP", "WOOKLPK", "YOOWKY"], cap = 5, hard = true},  # 47: p = 0.008, traps 2, nodes 1223
	{lanes = ["LWBL", "WLKK", "BKO", ""], queues = ["BPKOYB", "PYLYWO", "PWOYP"], cap = 5, hard = true},  # 48: p = 0.008, traps 3, nodes 508
	{lanes = ["LOWP", "KPLL", ""], queues = ["KOKOKLY", "WWBYWPB", "BBPYOY"], cap = 5, hard = true},  # 49: p = 0.007, traps 2, nodes 1052
	{lanes = ["OOPK", "YBOB", ""], queues = ["PWPWPOL", "YLBYBKW", "KLWYLK"], cap = 5, hard = true},  # 50: p = 0.006, traps 4, nodes 934
]


static func count() -> int:
	return ALL.size()


static func get_level(i: int) -> Dictionary:
	return ALL[clampi(i, 0, ALL.size() - 1)]
