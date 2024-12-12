// data cleaning

qui {

    if 1 {
        // centering for age
        noi di "Centering age..................", _continue
        gen age_centered = don_age - 50
        label variable age_centered "Age (Centered By 50)"
        noi di "Done"
        // create a marker for age >= 50
        noi di "Establishing binary variable for age >= 50..................", _continue
        gen age_50 = !(don_age < 50)
        noi di "Done"
    }

    if 2 {
        // destring gender
        noi di "Cleaning for gender..................", _continue
        capture drop gender
        encode don_gender, generate(gender)
        levelsof gender, local(helper)
        tokenize `helper'
        local pos = `1' + 1
        replace gender = `pos' - gender
        capture label drop gender
        label define gender 0 "Male" 1 "Female"
        label values gender gender
        label variable gender "Gender"
        noi di "Done"
    }

    if 3 {
        // destring race
        noi di "Cleaning for race..................", _continue
        capture drop race
        /*
        encode don_race_srtr, generate(race)
        levelsof race, local(helper)
        tokenize `helper'
        local pos = `1' - 1
        replace race = race - `pos'
        levelsof don_race_srtr, local(race_levels)
        local race_lab_helper
        local race_ct = 0
        foreach i in `race_levels' {
            local race_ct = `race_ct' + 1
            local str_helper : di strlower("`i'")
            local str_helper : di `""`str_helper'""'
            local race_lab_helper `race_lab_helper' `race_ct' `str_helper'
        }
        capture label drop race
        label define race `race_lab_helper'
        label values race race
        */
        // white = 8 White
        // Black = 16
        // Hispanic/Latino = 2000
        // Other = all except 1024
        gen race = 1 if don_race == 8
        replace race = 2 if don_race == 16
        replace race = 3 if don_race == 2000
        replace race = 4 if missing(race) & !missing(don_race) & don_race != 1024
        capture label drop race
        label define race 1 "White" 2 "Black" 3 "Hispanic" 4 "Other"
        label values race race
        label variable race "Race/Ethnicity"
        noi di "Done"
    }

    if 4 {
        // cleaning for education
        noi di "Cleaning for education..................", _continue
        capture drop education
        recode don_education ///
            (1/3=1) ///
            (4=2) ///
            (5=3) ///
            (6=4) ///
            (996 998=.) ///
            , gen(education)
        capture label drop education
        label define education ///
            1 "<HighSchool" ///
            2 "AttendedCollege" ///
            3 "CollegeGraduate" ///
            4 "PostCollege"
        label values education education
        label variable education "Highest Level of Education"
        noi di "Done"
    }

    if 5 {
        // cleaning for donor relationship
        noi di "Cleaning for donor relationship..................", _continue
        capture drop relation
        recode don_relationship_ty 1/4 = 1 nonm = 2, gen(relation)
        capture label drop relation
        label define relation 1 "First-Degree Relationship" 2 "Non-First-Degree Relationship"
        label values relation relation
        label variable relation "Donor Relationship"
        noi di "Done"
    }

    if 6 {
        // cleaning for diabete history
        noi di "Cleaning for diabetes history..................", _continue
        capture drop diabete
        gen diabete = 0 if don_diab == "N"
        replace diabete = 1 if don_diab == "Y"
        replace diabete = 0 if missing(diabete)
        capture label drop diabete
        label define diabete 0 "No" 1 "Yes"
        label values diabete diabete
        label variable diabete "Diabetes History"
        noi di "Done"
    }

    if 7 {
        // cleaning for hypertension history
        noi di "Cleaning for hypertension history..................", _continue
        capture drop hypertension
        recode don_hist_hyperten ///
            (1=0) ///
            (2/5=1) ///
            (998=.) ///
            ,gen(hypertension)
        replace hypertension = 0 if hypertension != 1
        capture label drop hypertension
        label define hypertension ///
            0 "No" ///
            1 "Yes" 
        label values hypertension hypertension
        label variable hypertension "Hypertension History"
        noi di "Done"
    }

    if 8 {
        // cleaning for smoke history
        noi di "Cleaning for smoking history..................", _continue
        capture drop smoke
        encode don_hist_cigarette, gen(smoke)
        capture label drop smoke
        label define smoke ///
            1 "NoHistory" ///
            2 "Smoker" 
        label values smoke smoke
        label variable smoke "Smoking History"
        noi di "Done"
    }

    if 9 {
        // cleaning for bmi
        noi di "Cleaning for BMI..................", _continue
        capture drop bmi
        gen bmi = round(don_wgt_kg / (don_hgt_cm / 100) ^ 2)
        replace bmi = . if !inrange(bmi, 10, 70)
        capture drop bmi_centered
        gen bmi_centered = bmi - 24
        label variable bmi "Body Mass Index"
        noi di "Done"
    }

    if 10 {
        // cleaning for egfr
        noi di "Cleaning for eGFR..................", _continue
        capture drop creat
        gen creat = don_ki_creat_preop
        capture drop egfr
        gen ethblack = race == 2
        gen k = cond(gender == 1, 0.7, 0.9)
        gen alpha = cond(gender == 1, -0.329, -0.411)
        gen  egfr = 141 * min(creat / k, 1) ^ alpha  * ///
                        max(creat / k, 1) ^ -1.209 * ///             
                        0.993 ^ don_age * ///
                        1.018 ^ gender * ///
                        1.159 ^ (ethblack == 1) if !missing(creat)
        drop k alpha
        replace egfr = round(egfr)
        replace egfr = . if missing(creat)
        replace egfr = . if !inrange(egfr, 15, 200)
        local temp_vars creat ethblack k alpha
        foreach i in `temp_vars' {
            capture drop `i'
        }
        label variable egfr "Estimated Glomerular Filtration Rate"
        capture drop egfr_centered
        gen egfr_centered = egfr - 90
        noi di "Done"
    }

    if 11 {
        // conducting an interaction term between age_50 and race
        noi di "Creating interaction terms..................", _continue
        levelsof race, local(r_helper)
        foreach i in `r_helper' {
            local lab : value label race
            local r_var : label `lab' `i'
            local r_str : di "`r_var'"
            forvalues j = 0/1 {
                local var_str : di "`r_str'X`j'age50"
                capture drop `var_str'
                gen `var_str' = 1 if (race == `i') & (age_50 == `j')
                replace `var_str' = 0 if missing(`var_str')
                noi di " `var_str' created"
            }
        }
        noi di "Done"
    }

    if 12 {
        // centering for systolic blood pressure
        noi di "Centering systolic blood pressure..................", _continue
        capture drop sbp_centered
        gen sbp_centered = don_bp_preop_syst - 120
        noi di "Done"
    }
	
	if 13 {
		// creating a binary variable indicating before/after 2014
		noi di "Creating p2014 groups.............................", _continue
		capture drop p2014
		gen p2014 = 0 if !missing(don_recov_dt)
		replace p2014 = 0 if !missing(don_recov_dt) & (don_recov_dt > d(31dec2013))
		noi di "Done"
	}

    noi di "Data cleaning completed"
}