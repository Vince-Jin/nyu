// Overall do file
qui {

    // establish settings
    if 1 {
        clear
        set more off
        set varabbrev on
        cls
		macro drop _all

        // establish slash
        if (c(os) == "Windows") {
            global slash "\"
        }
        else {
            global slash "/"
        }

        // check if basic path information is up
        global root : di "`c(pwd)'"
        if ("${root}" == "") {
            noi di "Please enter the root path folder for this analysis."
            noi di "Press enter to use the folder underwhich this do file is saved.", _request(root)

            if ("${root}" == "") {
                global root : di "`c(pwd)'"
            }
            capture cd "${root}"
            if !(_rc) {
                noi di "Root path setted to: ${root}"
            }
            else {
                noi di as error "Fatal Error: Root path not found."
                exit
            }
        }
        else {
            capture cd "${root}"
            if !(_rc) {
                noi di "Root path setted to: ${root}"
            }
            else {
                noi di as error "Fatal Error: Root path not found."
                exit
            }
        }
        capture log close
        log using "analysis_log.txt", text replace

        // check if the data path is up
        global data : di "`c(pwd)'${slash}data"
        if ("${data}" == "") {
            noi di "Please enter the data path folder for this analysis."
            noi di "Press enter to use the data folder under root path.", _request(data)

            if ("${data}" == "") {
                global data : di "${root}${slash}data"
            }
            capture cd "${data}"
            if !(_rc) {
                noi di "Data path setted to: ${data}"
            }
            else {
                noi di as error "Fatal Error: Data path not found."
                exit
            }
            cd "${root}"
        }
        else {
            capture cd "${data}"
            if !(_rc) {
                noi di "Data path setted to: ${data}"
            }
            else {
                noi di as error "Fatal Error: Data path not found."
                exit
            }
            cd "${root}"
        }
    }

    // now basic path are established, start output settings
    if 2 {
        cd "${root}"
        capture mkdir "output"
        global output "${root}${slash}output"
        capture cd "${output}"
        if !(_rc) {
            noi di "Output path setted to: ${output}"
        }
        else {
            noi di as error "Fatal Error: Output path not found."
            exit
        }
        cd "${output}"
        capture mkdir table1
        global tab "${output}${slash}table1"
        capture cd "${tab}"
        if !(_rc) {
            noi di "table1 sub folder succesffully created."
        }
        else {
            noi di as error "Fatal Error: failed to create table1 sub folder."
            exit
        }
        cd "${output}"
        capture mkdir matrices
        global mat "${output}${slash}matrices"
        capture cd "${mat}"
        if !(_rc) {
            noi di "matrices sub folder succesffully created."
        }
        else {
            noi di as error "Fatal Error: failed to create matrices sub folder."
            exit
        }
        cd "${output}"
        capture mkdir figures
        global fig "${output}${slash}figures"
        capture cd "${fig}"
        if !(_rc) {
            noi di "figures sub folder succesffully created."
        }
        else {
            noi di as error "Fatal Error: failed to create figures sub folder."
            exit
        }
        cd  "${output}"
        capture mkdir sinfo
        global sin "${output}${slash}sinfo"
        capture cd "${sin}"
        if !(_rc) {
            noi di "sinfo sub folder succesffully created."
        }
        else {
            noi di as error "Fatal Error: failed to create sinfo sub folder."
            exit
        }
        cd "${root}"
    }

    if 3 {
        // load data
        capture use "${data}${slash}donor_live.dta", clear
        if (`c(N)' != 0) {
            noi di "Data loaded successfully."
        }
        else {
            noi di as error "Fatal Error: Data not found."
            exit
        }
    }

    if 4 {
        // obtain mortality censoring date
        /*
        noi di "Please specify the censoring date for mortality status"
        noi di "in the format of 'ddmmmyyyy', for example: "
        noi di "12/31/2011 -> 31dec2011"
        noi di "Press enter to use 31 Dec 2011", _request(mort_censor_date)
        */
        if ("${mort_censor_date}" == "") {
            global mort_censor_date : di  `"d(31dec2011)"'
        }
        else {
            global mort_censor_date : di  `"d(${mort_censor_date})"'
        }

        // obtain esrd censoring date
        /*
        noi di "Please specify the censoring date for esrd status"
        noi di "in the format of 'ddmmmyyyy', for example: "
        noi di "12/31/2011 -> 31dec2011"
        noi di "Press enter to use 31 Dec 2011", _request(esrd_censor_date)
        */

        if ("${esrd_censor_date}" == "") {
            global esrd_censor_date : di  `"d(31dec2011)"'
        }
        else {
            global esrd_censor_date : di  `"d(${esrd_censor_date})"'
        }

        // conduct mortality follow up period
        gen died = !missing(pers_ssa_death)
        replace died = 0 if pers_ssa_death > ${mort_censor_date}
        gen d_censor = min(pers_ssa_death, ${mort_censor_date})
        noi tab died
        g dfup = d_censor - don_recov_dt
        replace dfup = .5 if dfup == 0
        
        drop if !inrange(dfup,0,10000)

        // conduct esrd follow up period
        gen esrd = !missing(pers_esrd_first_service_dt)
        replace esrd = 0 if pers_esrd_first_service_dt > ${esrd_censor_date} | pers_esrd_first_service_dt > pers_ssa_death

        gen e_censor = min(pers_esrd_first_service_dt, pers_ssa_death, ${esrd_censor_date})
        noi tab esrd
        g efup = e_censor - don_recov_dt
        replace efup = .5 if efup == 0.5

        drop if !inrange(efup, 0, 10000)
    }

    if 5 {
        /*
        Variable list:
        age             don_age        cont
        gender          don_gender     cat (string "F" "M")
        race            don_race_srtr  cat (string "ASIAN" "BLACK" "MULTI" "NATIVE" "PACIFIC" "WHITE")
        education       don_education  cat (int 1-6, 996, 998) 
        recode don_education ///
            (1/3=1) ///
            (4=2) ///
            (5=3) ///
            (6=4) ///
            (996 998=.) ///
            , gen(don_educat)
            label define Don_educat ///
            1 "<HighSchool" ///
            2 "AttendedCollege" ///
            3 "CollegeGraduate" ///
            4 "PostCollege"
            label values don_educat Don_educat
            label var don_educat "Highest Level of Education"
        diabetes        don_diab       cat (string "N" "U" "Y")
        diabete_med     don_diab_treat cat (int 1-6, =49 (diab == 1) - 1(missing))
        hypertension    don_hist_hyperten cat (int 1-5, 998)
        recode don_hist_hyperten ///
            (1=2) ///
            (2 8 9=1) ///
            (.=.) ///
            ,gen(don_hyperten)
            label define Don_hyperten ///
            1 "No History" ///
            2 "History of Hypertension" 
            label values don_hyperten Don_hyperten
        hyperten_med    don_hyperten_postop cat (string "N" "U" "Y")
        smoke           don_hist_cigarette  cat (string "N" "Y")
        recode don_hist_cigarette ///
            (1=2) ///
            (2=1) ///
            ,gen(don_smoke)
            label define Don_smoke ///
            1 "NoHistory" ///
            2 "Smoker" 
            label values don_smoke Don_smoke
        sys_bp          don_bp_preop_syst cont
        dia_bp          don_bp_preop_diast cont
        bmi             missing         calculate( weight/(height/100)^2 weight: don_wgt_kg height: don_hgt_cm)
        gen don_bmi=round(don_wgt_kg/(don_hgt_cm/100)^2)
        replace don_bmi=. if !inrange(don_bmi,10,70)
        recode don_bmi ///
        (10/24=1) ///
        (25/29=2) ///
        (30/70=3) ///
        ,gen(don_bmicat)
        label define Don_bmicat ///
        1 "<25" ///
        2 "25-29" ///
        3 "30+"
        label values don_bmicat Don_bmicat
        label var don_bmicat "Calculated BMI at Donation, kg/m2"
        ghb             missing
        creatinine      don_ki_creat_preop cont
        egfr
        gen ethblack=don_race_eth==2
        gen     k =    cond(don_female==1, 0.7, 0.9)
        gen alpha =    cond(don_female==1, -0.329, -0.411)
        gen  don_egfr = 141*min(creat/k, 1)^alpha  * ///
                        max(creat/k, 1)^-1.209 * ///             
                    0.993^don_age        * ///
                    1.018^don_female             * ///
                    1.159^(ethblack==1) if !missing(creat)
        drop k alpha
        replace don_egfr=round(don_egfr)
        replace don_egfr=. if missing(creat)
        replace don_egfr=. if !inrange(don_egfr,15,200)
        recode don_egfr ///
            (min/79=1) ///
            (80/89=2) ///
            (90/max=3) ///
            ,gen(don_egfrcat)
            label define don_egfrcat ///
            1 "<80" ///
            2 "80-89" ///
            3 "90+"
        label values don_egfrcat don_egfrcat
        */

        noi do data_cleaning.do
        save "${data}${slash}donor_live_cleaned.dta", replace
    }

    if 6 {
        // load table 1 programs
        qui do "table1_fena.ado"
        cd "${tab}"
        // conduct overall table 1
        noi table1_fena, var(don_age bmi don_bp_preop_syst egfr gender diabete hypertension smoke relation race education p2014) excel("Table1") missingness
        // conduct age50 table 1
        preserve
        keep if age_50 == 1
        noi table1_fena, var(don_age bmi don_bp_preop_syst egfr gender diabete hypertension smoke relation race education p2014) excel("Table1_age50") missingness
        restore
    }

    if 7 {
        // conducting survival analysis
        set varabbrev off
        // mortality overall
        noi stset dfup, failure(died == 1) scale(365.25)
        sts graph, fail title("Cumulative Incidence of Mortality Among Donor Population") subtitle("From Date of Recovery From Donation") risktable(, size(small)) ytitle("Cumulative Incidence") xtitle("Follow Up Time (Years)") per(100)
        noi graph export "${fig}${slash}KM_Mortality_Overall.png", as(png) replace

        // cox
        capture drop s0
        noi stcox age_centered bmi_centered sbp_centered egfr_centered ib1.gender i.diabete i.hypertension i.smoke i.relation i.race ib3.education i.p2014, basesurv(s0)
        matrix cox_b = e(b)'
        matrix cox_var = e(V)'
        matrix cox = r(table)'

        cd "${mat}"
        putexcel set "Cox_Mort_Overall.xlsx", replace
        putexcel A1 = matrix(cox), names
        putexcel set "Beta_Mort_Overall.xlsx", replace
        putexcel A1 = matrix(cox_b), names
        putexcel set "Var_Mort_Overall.xlsx", replace
        putexcel A1 = matrix(cox_var), names

        preserve
        keep s0 _st _t _d _t0
        noi export delimited using "Sinfo_Mort_Overall.csv", replace
        restore 

        // esrd overall
        noi stset efup, failure(esrd == 1) scale(365.25)
        sts graph, fail title("Cumulative Incidence of ESRD Among Donor Population") subtitle("From Date of Recovery From Donation") risktable(, size(small)) ytitle("Cumulative Incidence") xtitle("Follow Up Time (Years)") per(100)
        noi graph export "${fig}${slash}KM_ESRD_Overall.png", as(png) replace

        // cox
        capture drop s0
        noi stcox age_centered bmi_centered sbp_centered egfr_centered ib1.gender i.diabete i.hypertension i.smoke i.relation i.race ib3.education i.p2014, basesurv(s0)
        matrix cox_b = e(b)'
        matrix cox_var = e(V)'
        matrix cox = r(table)'

        cd "${mat}"
        putexcel set "Cox_ESRD_Overall.xlsx", replace
        putexcel A1 = matrix(cox), names
        putexcel set "Beta_ESRD_Overall.xlsx", replace
        putexcel A1 = matrix(cox_b), names
        putexcel set "Var_ESRD_Overall.xlsx", replace
        putexcel A1 = matrix(cox_var), names

        preserve
        keep s0 _st _t _d _t0
        noi export delimited using "Sinfo_ESRD_Overall.csv", replace
        restore

        // age 50
        tempfile overall
        save `overall', replace

        keep if age_50 == 1

        // mortality age 50
        noi stset dfup, failure(died == 1) scale(365.25)

        sts graph, fail title("Cumulative Incidence of Mortality Among Aged (>= 50) Donor Population") subtitle("From Date of Recovery From Donation") risktable(, size(small)) ytitle("Cumulative Incidence") xtitle("Follow Up Time (Years)") per(100)
        noi graph export "${fig}${slash}KM_Mortality_Age50.png", as(png) replace

        // cox
        capture drop s0
        noi stcox age_centered bmi_centered sbp_centered egfr_centered ib1.gender i.diabete i.hypertension i.smoke i.relation i.race ib3.education i.p2014, basesurv(s0)
        matrix cox_b = e(b)'
        matrix cox_var = e(V)'
        matrix cox = r(table)'

        cd "${mat}"
        putexcel set "Cox_Mort_Age50.xlsx", replace
        putexcel A1 = matrix(cox), names
        putexcel set "Beta_Mort_Age50.xlsx", replace
        putexcel A1 = matrix(cox_b), names
        putexcel set "Var_Mort_Age50.xlsx", replace
        putexcel A1 = matrix(cox_var), names

        preserve
        keep s0 _st _t _d _t0
        noi export delimited using "Sinfo_Mort_Age50.csv", replace
        restore

        // esrd age 50
        noi stset efup, failure(esrd == 1) scale(365.25)

        sts graph, fail title("Cumulative Incidence of ESRD Among Aged (>= 50) Donor Population") subtitle("From Date of Recovery From Donation") risktable(, size(small)) ytitle("Cumulative Incidence") xtitle("Follow Up Time (Years)") per(100)
        noi graph export "${fig}${slash}KM_ESRD_Age50.png", as(png) replace

        // cox
        capture drop s0
        noi stcox age_centered bmi_centered sbp_centered egfr_centered ib1.gender i.diabete i.hypertension i.smoke i.relation i.race ib3.education i.p2014, basesurv(s0)
        matrix cox_b = e(b)'
        matrix cox_var = e(V)'
        matrix cox = r(table)'

        cd "${mat}"      
        putexcel set "Cox_ESRD_Age50.xlsx", replace
        putexcel A1 = matrix(cox), names
        putexcel set "Beta_ESRD_Age50.xlsx", replace
        putexcel A1 = matrix(cox_b), names
        putexcel set "Var_ESRD_Age50.xlsx", replace
        putexcel A1 = matrix(cox_var), names

        preserve
        keep s0 _st _t _d _t0
        noi export delimited using "Sinfo_ESRD_Age50.csv", replace
        restore

        // interaction
        use `overall', clear

        // mortality
        noi stset dfup, failure(died == 1) scale(365.25)
        capture drop s0
        noi stcox age_centered i.age_50##i.race bmi_centered sbp_centered egfr_centered ib1.gender i.diabete i.hypertension i.smoke i.relation ib3.education i.p2014, basesurv(s0)
        matrix cox_b = e(b)'
        matrix cox_var = e(V)'
        matrix cox = r(table)'

        cd "${mat}"
        putexcel set "Cox_Mort_Interaction.xlsx", replace
        putexcel A1 = matrix(cox), names
        putexcel set "Beta_Mort_Interaction.xlsx", replace
        putexcel A1 = matrix(cox_b), names
        putexcel set "Var_Mort_Interaction.xlsx", replace
        putexcel A1 = matrix(cox_var), names

        preserve
        keep s0 _st _t _d _t0
        noi export delimited using "Sinfo_Mort_Interaction.csv", replace
        restore

        // esrd
        noi stset efup, failure(esrd == 1) scale(365.25)
        capture drop s0
        noi stcox age_centered i.age_50##i.race bmi_centered sbp_centered egfr_centered ib1.gender i.diabete i.hypertension i.smoke i.relation ib3.education i.p2014, basesurv(s0)
        matrix cox_b = e(b)'
        matrix cox_var = e(V)'
        matrix cox = r(table)'

        cd "${mat}"
        putexcel set "Cox_ESRD_Interaction.xlsx", replace
        putexcel A1 = matrix(cox), names
        putexcel set "Beta_ESRD_Interaction.xlsx", replace
        putexcel A1 = matrix(cox_b), names
        putexcel set "Var_ESRD_Interaction.xlsx", replace
        putexcel A1 = matrix(cox_var), names

        preserve
        keep s0 _st _t _d _t0
        noi export delimited using "Sinfo_ESRD_Interaction.csv", replace
        restore

    }

    if 8 {
		cd "${root}"
        noi do donor_st.do
    }
}