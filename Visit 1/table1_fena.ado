qui {
	capture program drop table1_fena
	program define table1_fena

		qui {
			
			syntax [if] [, var(string) by(varname) title(string) excel(string) catt(int 15) missingness]
			
			// first detect varaible type
			if 1 {
				noi di "Detecting Variable Types"
				// in case only by variable was specified
				if (("`by'" != "") & ("`var'" == "")) {
					ds
					local var_helper = r(varlist)
					local var : di stritrim(subinstr("`var_helper'", "`by'", "", .))
				}
				noi var_type, var(`var') catt(`catt')
				if (strupper("${terminator}") == "EXIT") {
					exit
				}				
				if (strupper("${terminator}") != "EXIT") {
					noi missing_detect, v(${terminator})
				}
				
				// double verify the variable types 
				// ask for user input
				noi di "Please indicate variables to modify, separated by space (e.g.: aaa bbb ccc)"
				noi di "Press enter to skip modification"
				// , _request(var_change)
				if ("${var_change}" != "") {
					local bstring : di "${bin}"
					local castring : di "${cat}"
					local costring : di "${con}"
					foreach i in ${var_change} {
						
						noi di "Please enter the correct variable type for" " variable " "`i'" " (1-binary 2-categorical 3-continuous):", _request(vtype)
						
						local bstring : di subinstr("`bstring'", "`i'", "", 1)
						local castring : di subinstr("`castring'", "`i'", "", 1)
						local costring : di subinstr("`costring'", "`i'", "", 1)
						
						if (${vtype} == 1) {
							local bstring : di "`bstring'" " " "`i'"
						}
						else if (${vtype} == 2) {
							local castring : di "`castring'" " " "`i'"
						}
						else if (${vtype} == 3) {
							local costring : di "`costring'" " " "`i'"
						}
						
						local bstring : di stritrim(strtrim("`bstring'"))
						local castring : di stritrim(strtrim("`castring'"))
						local costring : di stritrim(strtrim("`costring'"))

						
					}
					global bin `bstring'
					global cat `castring'
					global con `costring'
					noi di "Current Variable Types: "
					noi di "Binary Variables:"
					noi di "${bin}"
					noi di "Categorical Variables: "
					noi di "${cat}"
					noi di "Continuous Variables: "
					noi di "${con}"
				}
				
				// call the table1 program generate table 1
				noi di as error "Generating Table1"
				noi table1_creation `if', bin(${bin}) cat(${cat}) con(${con}) title(`title') excel(`excel') by(`by') `missingness' orders(`var')
				noi di ""
				noi di as error "Table 1 saved as `excel' to the following directory:"
				noi di in g "`c(pwd)'"
			}
			
		}

	end
}

qui {
	
	capture program drop var_type
	program define var_type
	
		qui {
			
			// determine the type of each variable being taken in
			// should take list of variables
			// default should be everything
			// end product:
			// three global macro to for binary, categorical, continuous variables
			syntax [, var(string) catt(int 15)]
			
			// sets up proper variable list for action
			if ("`var'" != "") {
				local vlist `var'
			} 
			else if ("`var'" == "") {
				ds
				local vlist `r(varlist)'
			}
			
			// determine if any of the variable specified is not in the dataset
			noi missing_detect, v(`vlist')

			if (strupper("${terminator}") == "EXIT") {
				noi di as error "WARNING: User Requested To Terminate The Program"
				exit
			}
			else {
				local vlist ${terminator}
			}

			// create returning global macros
			global bin
			global cat
			global con
			global tran
			
			// start to detect
			foreach i in `vlist' {
				/*
				levelsof `i', local(l1) s("!*!")
				
				local l2 : di subinstr(`"`l1'"', "!*!", "", .)
				local ln1 = strlen(`"`l1'"')
				local ln2 = strlen(`"`l2'"')
				local ln_diff = (`ln1' - `ln2') / 3
				*/
				local ln_diff = -1
				levelsof `i', local(l1)
				foreach var_val in `l1' {
					local ln_diff = `ln_diff' + 1
				}
				
				if (`ln_diff' == 1 | `ln_diff' < 1) {
					global bin : di "${bin}" " " "`i'"
				}
				else if (`ln_diff' > 1 & `ln_diff' < `catt') {
					global cat : di "${cat}" " " "`i'"
				}
				else if (inrange(`ln_diff', (`catt' - 1), (`catt' - 1 + 15))) {
					global tran : di "${tran}" " " "`i'"
					global cat : di "${cat}" " " "`i'"
				}
				else {
					global con : di "${con}" " " "`i'"
				}
				
			}
			
			// display results
			noi di "Detected binary variables: "
			noi di "${bin}"
			noi di "Detected categorical variables: "
			noi di "${cat}"
			noi di "Detected continuous variables: "
			noi di "${con}"
			
			if ("${tran}" != "") {
				noi di as error "WARNING: Variables Require User Attention"
				noi di in g "${tran}"
			}
			
			
		}
	
	end
	
	capture program drop missing_detect
	program define missing_detect
		qui {
			syntax, v(string)
			ds
			local testing `r(varlist)'
			local missing
			foreach i in `v'{	
				if (strpos("`testing'", "`i'") == 0) {
					local missing : di "`missing'" " " "`i'"
					
				}
			}
			
			if ("`missing'" == "") {
				noi di in g "Variable check cleared"
				global terminator `v'
			}
			else if ("`missing'" != "") {				
				noi di ""
				noi di in g "Variables below not found in current dataset: "
				noi di "`missing'"
				noi di "Please re-enter variable list for the program"
				noi di "(Enter exit to terminate the program)"
				// , _request(terminator)
				
				if (strupper("${terminator}") == "EXIT") {
					exit
				}				
				if (strupper("${terminator}") != "EXIT") {
					noi missing_detect, v(${terminator})
				}
				
			}
		}
	end
	
}

qui {
	capture program drop ind_translator
	program define ind_translator
		syntax, row(int) col(int)

		// tokenize the alphabet
		local alphabet "`c(ALPHA)'"
		tokenize `alphabet'
		// now translate col
		local col_helper = `col'
		
		
		while (`col_helper' > 0) {
			local temp_helper2 = (`col_helper' - 1)
			local temp_helper = mod(`temp_helper2', 26) + 1
			local col_name : di "``temp_helper''" "`col_name'"
			local col_helper = (`col_helper' - `temp_helper') / 26
		} 
		
		
		// generate a global macro that can be used in main program
		global ul_cell "`col_name'`row'"
		
	end
}

qui {
	capture program drop table1_creation
	program define table1_creation

		syntax [if] [, title(string) bin(string) cat(string) con(string) foot(string) by(varname) excel(string) missingness orders(string)]
		
		qui {
			
			preserve
			
			// check if
			if ("`if'" != "") {
				keep `if'
			}
			
			// grant default value to excel and title
			if 2 {
				if ("`title'" == "") {
					local title : di "Table 1: Demographics"
				}
				if ("`excel'" == "") {
					local excel : di "Table 1 Outputs"
				}
				if ("`orders'" == "") {
					ds
					local orders `r(varlist)'
				}
			}
			
			// generate excel file
			if 3 {
				putexcel set "`excel'", replace
			}
			
			// prepare excel row/col
			if 4 {
				local erc = 1
				local ecc = 1
				global ind : di "ind_translator, row(" "`" "erc" "'" ") col(" "`" "ecc" "'" ")"
			}
			
			// prepare indentation
			if 5 {
				local col1: di "_col(40)"
				local col2: di "_col(50)"
				local cfac = 20
				local csep = 60
			}
			
			// run byvar checker
			if 7 {
				local dual_screener = 0
				local var_screener `con' `bin' `cat'
				foreach var in `var_screener' {
					if ("`by'" == "`var'") {
						local dual_screener = 1
					}
				}
				if (`dual_screener' == 1) {
					noi di as error "ERROR: The stratifying variable should not be inputted as table 1 variable"
					noi di in g " "
					exit
				}
			}
			
			// get title line and total N
			if 6 {
				noi di in g "`title'"
				ind_translator, row(`erc') col(`ecc')
				putexcel ${ul_cell} = "`title'"
				noi di "N=" "`c(N)'"
				local erc = `erc' + 1
				${ind}
				putexcel ${ul_cell} = "N=`c(N)'"
			}
			
			// deal with byvar
			local by01 = 1
			if ("`by'" == "") {
				// capture drop byvar_helper
				gen byvar_helper = 1
				local by byvar_helper
				local by01 = 0
			}

			// run through byvar
			if 8 {
				levelsof `by'
				local b_vals = r(levels)
				/* for now:
				if no byvar - b_vals = 1
				if byvar - b_vals = r(levels)
				*/
				// gather label information to print out byvar line
				local by_l : value label `by'
				// print out by line
				local cheader = 0
				// detect byvar type
				local bstringvar = 1
				local b_if : di ("`" + "by" + "'" + " == " + `"""' +"`" + "k" + "'" + `"""') 
				qui capture confirm string var `by'
				if _rc {
					local bstringvar = 0
					local b_if : di ("`" + "by" + "'" + " == " + "`" + "k" + "'")
				}
				
				if ("`by'" != "byvar_helper") {
					local erc = `erc' + 1
					foreach i in `b_vals' {
						local cheader = `cheader' + 1
						local ctemp = `csep' +  `cfac' * (`cheader' - 1)
						local col_s : di "_col(`ctemp')"
						local ecc = `ecc' + 1
						// detect if value label exist
						// if yes, label value i
						// if no, keep i
						if ("`by_l'" == "") {
							local val_lab : di "`i'"
						}
						else if ("`by_l'" != "") {
							local val_lab : label `by_l' `i'
						}
						if (`bstringvar' == 1) {
							count if `by' == "`i'"
						}
						else {
							count if `by' == `i'
						}
						local total = r(N)
						noi di `col_s'  "`val_lab'" " " "(n=`total')", _continue
						${ind}
						putexcel ${ul_cell} = "`val_lab' (n=`total')"
					}
					noi di ""
				}
				local ecc = 1
				local cheader = 0
				// get some constant for byvar
				foreach i in `b_vals' {
					if (`bstringvar' == 1) {
						count if `by' == "`i'"
					}
					else {
						count if `by' == `i'
					}
					local cnt`i' = r(N)
				}
			}
			
			// run through continuous variable
			local bincat `bin' `cat'
			foreach var in `orders' {
				if (strpos("`con'", "`var'") != 0) {
					// print out the variable
					// first detect if variable label exist
					local var_l : variable label `var'
					if ("`var_l'" == "") {
						local var_lab : di "`var'"
					}
					else if ("`var_l'" != "") {
						local var_lab : di "`var_l'"
					}
					// no need to detect value label since it is continuous
					noi di "`var_lab'" ", median[IQR]", _continue
					local erc = `erc' + 1
					${ind}
					putexcel ${ul_cell} = "`var_lab', median[IQR]"
					// detect if string var accidentally got into cont vars
					local stringvar = 1
					qui capture confirm string var `var'
					if _rc {
						local stringvar = 0
					}
					if (`stringvar' == 1) {
						local ctemp = `csep'
						local col_s : di "_col(`ctemp')"
						noi di as error `col_s' "`var' is in string format and not valid as continuous variables", _continue
						local ecc = `ecc' + 1
						${ind}
						putexcel ${ul_cell} = "`var' is in string format and not valid as continuous variables"
					}
					else {
						local cheader = 0
						// loop through byvar is enough
						foreach k in `b_vals' {
							local cheader = `cheader' + 1
							sum `var' if `b_if', detail
							local med = r(p50)
							local lq = r(p25)
							local hq = r(p75)
							local m_iqr : di %2.1f `med' "[" %2.1f `lq' ", " %2.1f `hq' "]"
							local ctemp = `csep' + `cfac' * (`cheader' - 1)
							local col_s : di "_col(`ctemp')"
							noi di `col_s' "`m_iqr'", _continue
							local ecc = `ecc' + 1
							${ind}
							putexcel ${ul_cell} = "`m_iqr'"
						}
					}
					noi di in g ""
					local ecc = 1
				}
				else if (strpos("`bincat'", "`var'") != 0) {
					// run through binary and categorical variable
					// print out the variable
					// first detect if variable label exist
					
					// detect if this var is string or not
					local stringvar = 1
					qui capture confirm string var `var'
					if _rc {
						local stringvar = 0
					}
					
					local var_l : variable label `var'
					if ("`var_l'" == "") {
						local var_lab : di "`var'"
					}
					else if ("`var_l'" != "") {
						local var_lab : di "`var_l'"
					}
					// then detect if value label exist
					local val_l01 = 0
					local val_l : value label `var'
					if ("`val_l'" != "") {
						local val_l01 = 1
					}
					else if ("`val_l'" == "") {
						local val_l01 = 0
					}
					noi di "`var_lab'" ", n(%)"
					local erc = `erc' + 1
					${ind}
					putexcel ${ul_cell} = "`var_lab', n(%)"
					// print out each value line
					levelsof `var'
					local var_levels = r(levels)
					foreach j in `var_levels' {
						// zero out column counter to ensure columns align appropriately
						local cheader = 0
						if (`val_l01' == 1) {
							local val_lab : label `val_l' `j'
						}
						else if (`val_l01' == 0) {
							local val_lab : di "`j'"
						}
						// print j value
						noi di _col(4) "`val_lab'", _continue
						local erc = `erc' + 1
						${ind}
						putexcel ${ul_cell} = "    `val_lab'"
						// count and percentage
						foreach k in `b_vals' {
							if `stringvar' == 1 {
								count if `var' == "`j'" & `b_if'
							}
							else {
								count if `var' == `j' & `b_if'
							}
							local cnt = r(N)
							local per = `cnt' / `cnt`k'' * 100
							// assemble count and per
							local cp : di "`cnt'(" %2.1f `per' ")"
							// print out cnt and per
							local cheader = `cheader' + 1
							local ctemp = `csep' +  `cfac' * (`cheader' - 1)
							local col_s : di "_col(`ctemp')"
							noi di `col_s' "`cp'", _continue
							local ecc = `ecc' + 1
							${ind}
							putexcel ${ul_cell} = "`cp'"
						}
						noi di ""
						local ecc = 1
					}
				}
				
			}
			
			// missingness
			if ("`missingness'" == "missingness") {
				noi di ""
				local erc = `erc' + 1
				noi di in g "Missingness Information: "
				local erc = `erc' + 1
				local ecc = 1
				${ind}
				putexcel ${ul_cell} = "Missingness Information: "
				local mis_var `bin' `cat' `con'
				foreach var in `mis_var' {
					// display variable name
					local var_l : variable label `var'
					if ("`var_l'" == "") {
						local var_lab : di "`var'"
					}
					else if ("`var_l'" != "") {
						local var_lab : di "`var_l'"
					}
					noi di "`var_lab'", _continue
					local erc = `erc' + 1
					local ecc = 1
					${ind}
					putexcel ${ul_cell} = "`var_lab'"
					// display missingness
					count if missing(`var')
					local mis = r(N)
					local mis_per = `mis' / `c(N)' * 100
					local mis_per : di %3.2f `mis_per' "% missing"
					noi di _col(`csep') "`mis_per'"
					local ecc = `ecc' + 1
					${ind}
					putexcel ${ul_cell} = "`mis_per'"
				}
			}
		
		capture restore
		
		}
		
	end
}