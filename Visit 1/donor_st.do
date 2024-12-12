qui {
	cd "${output}"
	capture mkdir "d90"
	cd "${output}${slash}d90"
	use "${data}${slash}donor_live", clear
	
	capture drop race
	local val = 0
	levelsof don_race_srtr, local(races)
	gen race = .
	foreach i in `races' {
		local val = `val' + 1
		replace race = `val' if don_race_srtr == "`i'"
	}
	label define race 1 "Black" 2 "Multi-racial" 3 "White"
	
	// regroup to black, other/multi, white
	capture drop race2
	gen race2 = 1 if race == 2
	replace race2 = 3 if race == 6
	replace race2 = 2 if (!missing(race) & race2 != 1 & race2 != 3)
	
	capture drop p2014
	gen p2014 = 0 if !missing(don_recov_dt)
	replace p2014 = 1 if !missing(don_recov_dt) & (don_recov_dt > d(31dec2013))
	
	keep don_age don_gender race2 don_recov_dt pers_ssa_death_dt p2014
	rename race2 don_race
	
	gen died=!missing(pers_ssa_death_dt)
	replace died=0 if pers_ssa_death_dt>d(30dec2011)
	gen end_dt=min(pers_ssa_death_dt,d(30dec2011))
	tab died
	g days=end_dt-don_recov_dt
	replace days = .5 if days==0
	
	capture drop don_age_centered
	gen don_age_centered = don_age - 40
	
	drop if !inrange(days,0,10000)
	
	
	
	// recode gender
	capture drop gender
	gen gender = 2 if don_gender == "F"
	replace gender = 1 if don_gender == "M"
	rename don_gender gender_old
	rename gender don_gender
	
	// generate agegroup
	capture drop agecat
	gen agecat = 1 if !(don_age > 40)
	replace agecat = 2 if (don_age > 40 & don_age < 50)
	replace agecat = 3 if !missing(don_age) & !(don_age < 50)
	
	// censoring at 90 days
	capture drop d90
	gen d90 = 1 if died == 1 & !(days > 90)
	replace d90 = 0 if d90 != 1 & !missing(died)
	capture drop d90_fup
	gen d90_fup = days if !(days > 90)
	replace d90_fup = 90 if d90 == 0 & days > 90
	
	noi stset d90_fup, fail(d90 == 1)
	
	// sts graph, fail per(10000)
	
	capture drop s0
	noi stcox don_age ib2.don_gender ib3.don_race i.p2014, basesurv(s0)
	
	matrix beta = e(b)'
	matrix var = e(V)'
	
	putexcel set don_beta1, replace
	putexcel A1 = matrix(beta), names
	
	putexcel set don_var1, replace
	putexcel A1 = matrix(var), names
	preserve 
	keep _t _d s0
	export delimited "don_s0_complex.csv", replace
	restore
	
	capture drop s0
	noi stcox ib3.agecat ib2.don_gender ib3.don_race i.p2014, basesurv(s0)
	matrix beta = e(b)'
	matrix var = e(V)'
	
	putexcel set don_beta2, replace
	putexcel A1 = matrix(beta), names
	
	putexcel set don_var2, replace
	putexcel A1 = matrix(var), names
	
	preserve
	keep _t _d s0
	export delimited "don_s0_paper.csv", replace
	restore
	
}