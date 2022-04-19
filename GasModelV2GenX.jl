using JuMP, CPLEX
using CSV
using DataFrames
using DelimitedFiles

###### All units in model in mcm - converted to bcm before output

## To Dos:
# Introduce country, month specific heating demand mitigation
# for ireland, make it so that if production > demand, demand is set = production - exports

# Reading in CSVs
function initialize_data(folder::AbstractString)
    Base_year = raw"2223" # Just keep the last two digits of the year name - 19, 20, 21, 2223
    LNG_year = raw"2223" # Options - 21, 22, 2223, 25, 30
    stor_year = raw"22" # Options - 22, 25, 30 - Note: no new storage online between '21 and '22 and '23/no good dates provided

    
    imports = "ImportCaps.csv"
    trans = "TransmissionCap.csv"
    input = "Inputs"
    input_path = joinpath(folder, input)
    demand = "Demand"*Base_year*".csv"
    production = "Production"*Base_year*".csv"
    storage = "Storage.csv"
    countrylist = "CountryList.csv"
    sector = "SectorUse.csv"
    # rus = "RussiaReduc.csv"
    biogas = "Biogas.csv"

    country_path = joinpath(input_path, countrylist)
    country_df = CSV.read(country_path, header = 1, DataFrame)

    imp_path = joinpath(input_path, imports)
    imports_df = CSV.read(imp_path, header=1, DataFrame)

    trans_path = joinpath(input_path, trans)
    trans_in_df = CSV.read(trans_path, header=1, DataFrame) # in mcm per day - col is country from, row is country to
    trans_out_df = transposer(trans_in_df)
 
    demand_path = joinpath(input_path, demand)
    demand_df = CSV.read(demand_path, header=1, DataFrame)

    prod_path = joinpath(input_path, production)
    prod_df = CSV.read(prod_path, header=1, DataFrame)

    stor_path = joinpath(input_path, storage)
    stor_df = CSV.read(stor_path, header=1, DataFrame)

    sector_path = joinpath(input_path, sector)
    sector_df = CSV.read(sector_path, header=1, DataFrame)

    #rus_path = joinpath(input_path, rus)
    #rus_df = CSV.read(rus_path, header=1, DataFrame)

    biogas_path = joinpath(input_path, biogas)
    biogas_df = CSV.read(biogas_path, header = 1, DataFrame)

    check_LNG_year!(imports_df, LNG_year)
    check_stor_year!(stor_df, stor_year)

    return stor_df, prod_df, demand_df, trans_in_df, trans_out_df, imports_df, country_df, sector_df, biogas_df
end

function check_heating(input_path::AbstractString, low_chp::Bool)
    CHP4 = "SectoralReduction4CHPstandard.csv"
    CHP8 = "SectoralReduction8CHPstandard.csv"
    if low_chp == true
        path = joinpath(input_path, CHP4)
    else
        path = joinpath(input_path, CHP8)
    end
    sec_reduc_df = CSV.read(path, header=1, DataFrame)
    return sec_reduc_df
end

"""
# Select heating demand reduction strength
function check_heating(input_path::AbstractString, low_chp::Bool)
    nsec = 5
    nmonth = 24
    nheatopt = 4
    nindopt = 2
    file_names_df = CSV.read("C:\\Users\\mike_\\Documents\\ZeroLab\\EU_Gas_Model\\Inputs\\ReducCSVs.csv", header=1, DataFrame)
    scen_select_df = CSV.read("C:\\Users\\mike_\\Documents\\ZeroLab\\EU_Gas_Model\\Inputs\\ReducSelector.csv", header=1, DataFrame)
    nscen = nrow(file_names_df)
    ncountry = nrow(scen_select_df)
    heat_reduc_opt = Array{Float64, 3}(undef, (nheatopt, nmonth, 2))
    ind_reduc_opt = Array{Float64, 2}(undef, (nindopt, nmonth))
    chp_reduc_opt = Array{Float64, 2}(undef, (2, nmonth))
    sec_reduc_cc = Array{Float64, 3}(undef, (ncountry, nmonth, nsec))
    elec_reduc_base = [1,1,0.9,0.8,0.7,0.5,0.3,0.1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    counter = 1
    for k in file_names_df.File
        file_path = joinpath(input_path, k)
        file_df = CSV.read(file_path, header = 1, DataFrame)
        if counter <= nheatopt # heat scenarios
            for i in 1:2 
                for j in 1:nmonth
                    heat_reduc_opt[counter, j, i] = file_df[j, i]
                end
            end
        elseif counter >= 5 && counter <= 6
            for i in 1:nmonth
                ind_reduc_opt[counter-4, i] = file_df[i,1]
            end
        elseif counter >= 7 && counter <= 8
            for i in 1:nmonth
                chp_reduc_opt[counter-6, i] = file_df[i, 1]
            end
        end
        counter = counter + 1
    end
    for m in 1:ncountry
        for j in 1:nmonth
            scen_h = scen_select_df.Reduc_Heat[m]
            scen_i = scen_select_df.Reduc_Ind[m]
            sec_reduc_cc[m, j, 1] = elec_reduc_base[j]
            if low_chp == true
                sec_reduc_cc[m, j, 2] = chp_reduc_opt[1,j]
            else
                sec_reduc_cc[m, j, 2] = chp_reduc_opt[2,j]
            end
            sec_reduc_cc[m, j, 3] = ind_reduc_opt[scen_i,j]
            sec_reduc_cc[m, j, 4] = heat_reduc_opt[scen_h,j, 1]
            sec_reduc_cc[m, j, 5] = heat_reduc_opt[scen_h,j, 2]
        end
    end
    return sec_reduc_cc
end
"""

# Subselect for specific LNG build out assumptions
function check_LNG_year!(imports_df::DataFrame, LNG_year::AbstractString)
    # Check LNG year
    if LNG_year == raw"21"
        select!(imports_df, Not(:LNG_2022))
        select!(imports_df, Not(:LNG_2025))
        select!(imports_df, Not(:LNG_2030))
        select!(imports_df, Not(:LNG_2023))
        select!(imports_df, Not(:Baltic))
    elseif LNG_year == raw"22"
        select!(imports_df, Not(:LNG_2021))
        select!(imports_df, Not(:LNG_2025))
        select!(imports_df, Not(:LNG_2030))
        select!(imports_df, Not(:LNG_2023))
        #select!(imports_df, Not(:Baltic))
    elseif LNG_year == raw"25"
        select!(imports_df, Not(:LNG_2021))
        select!(imports_df, Not(:LNG_2022))
        select!(imports_df, Not(:LNG_2030))
        select!(imports_df, Not(:LNG_2023))
    elseif LNG_year == raw"30"
        select!(imports_df, Not(:LNG_2021))
        select!(imports_df, Not(:LNG_2022))
        select!(imports_df, Not(:LNG_2025))
        select!(imports_df, Not(:LNG_2023))
    elseif LNG_year == raw"2223"
        select!(imports_df, Not(:LNG_2021))
        select!(imports_df, Not(:LNG_2025))
        select!(imports_df, Not(:LNG_2030))
    end
end

# Subselect for specific storage assumptions
function check_stor_year!(stor_df::DataFrame, stor_year::AbstractString)
    #Check Storage year
    if stor_year == raw"22"
        select!(stor_df, :1)
    elseif stor_year == raw"25"
        select!(stor_df, :2)
    elseif stor_year == raw"30"
        select!(stor_df, :3)
    end
end

"""
function storage_ratios(demand_sector_reduc_df::AbstractArray, demand_df::AbstractDataFrame)
    leng = nrow(demand_df)
    nsec = 5
    winter_1 = Array{Float64}(undef, leng)
    winter_2 = Array{Float64}(undef, leng)
    winter_3 = Array{Float64}(undef, leng)
    ratio_a = Array{Float64}(undef, leng)
    ratio_b = Array{Float64}(undef, leng)
    for cc in 1:leng
        winter_1[cc] = sum(demand_sector_reduc_df[cc,t,sec] for t in 1:3, sec in 1:nsec)+sum(demand_df[cc,t] for t in 22:24)
        winter_2[cc] = sum(demand_sector_reduc_df[cc, t, sec] for t in 10:15, sec in 1:nsec)
        winter_3[cc] = sum(demand_sector_reduc_df[cc, t, sec] for t in 22:24, sec in 1:nsec)+sum(demand_sector_reduc_df[cc,t,sec] for t in 13:15, sec in 1:nsec)
        ratio_a[cc] = winter_2[cc]/winter_1[cc]
        ratio_b[cc] = winter_3[cc]/winter_1[cc]
        if ratio_a[cc] > 1
            ratio_a[cc] = 1
        end
        if ratio_b[cc] > 1
            ratio_b[cc] = 1
        end
        println(ratio_a[cc])
        println(ratio_b[cc])
    end
    return ratio_a, ratio_b
end
"""
# Create model
function initialize_model!(model::Model, demand_sector_reduc_df::AbstractArray, stor_df::AbstractDataFrame, prod_df::AbstractDataFrame, demand_df::AbstractDataFrame, trans_in_df::AbstractDataFrame, trans_out_df::AbstractDataFrame, imports_df::AbstractDataFrame, country_df::AbstractDataFrame, sector_df::AbstractDataFrame, biogas_df::AbstractDataFrame)#, ratio_a::AbstractArray, ratio_b::AbstractArray)
    issues = [2, 15, 17, 20, 21,22,24,25,26,27,28] # countries to weight in the objective
    # Introduce all countries demand
    leng = nrow(demand_df)
    nmonth = ncol(demand_df) # Make sure everything has same number of countries, months, and sectors
    nsec = ncol(sector_df)
    P = 10^5
    phased_LNG = true
    rus_cut = false
    if phased_LNG == true
        nrte = ncol(imports_df) - 1 # remove - 1 if not doing phased lng
    else
        nrte = ncol(imports_df)
    end
    Days_per_month = [31,28,31,30,31,30,31,31,30,31,30,31,31,28,31,30,31,30,31,31,30,31,30,31]#
    if rus_cut == true
        rus_df = [1,1,0.8,0.7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]#0.5,0.4,0.3,0.1
    elseif rus_cut == false
        rus_df = [1,1,0.8,0.7,0.5,0.4,0.3,0.1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    end
    # EU_tot_sec = [.15, .171, .254, .117, .308] # change to average of demand_df
    max_withdraw_day = 2022.401074
    max_inject_day = 1164.765988
    init_stor_fill_prop = 0.537
    derate_imports = 0.86
    derate_pipelines = 0.95 # Note: this derating of transmission pipelines is the most sensitive constraint. Dropping it to 0.9 from 0.95 results in an additional 1.34 bcm shortfall mostly in moldova and finland
    derate_LNG = 0.97
    LNG_market_cap = 124000 # mcm/yr
    # EU_stor_leg = 0.9
    prev_stor_peak = 0.9 # Historical is 0.77
    base_year = raw"2223"
    #lng_inc = 80+50
    #println(sector_df)
    #println(sec_reduc_df)


    # Setting demands and production up - equality to start with
    #@expression(model, demand_sector[cc = 1:leng, t = 1:nmonth, sec = 1:nsec], sector_df[cc,sec]*demand_df[cc,t])
    # inserting GenX outputs
    @variable(model, demand_eq[cc = 1:leng, t = 1:nmonth] >= 0)
    @expression(model, demand_sector_reduc[cc = 1:leng, t = 1:nmonth, sec = 1:nsec], demand_sector_reduc_df[cc,t,sec])
    @expression(model, demand[cc = 1:leng, t = 1:nmonth], sum(demand_sector_reduc[cc,t,sec] for sec in 1:nsec)) # _eq
    @constraint(model, c_demand_eq[cc = 1:leng, t = 1:nmonth], demand_eq[cc, t] >= demand[cc, t])
    #@expression(model, demand_eq[cc = 1:leng, t = 1:nmonth], demand_df[cc,t])
    @expression(model, demand_tot, sum(demand_eq[cc,t] for t in 1:nmonth, cc in 1:leng))

    # print(demand_tot)
#    @expression(model, demand_eq[cc = 1:leng, t = 1:nmonth], 0.802*demand_df[cc, t])
    @expression(model, prod_eq[cc = 1:leng, t = 1:nmonth], prod_df[cc,t])
    @expression(model, biogas_eq[cc = 1:leng, t = 1:nmonth], biogas_df[cc,1]*Days_per_month[t]) # Creates biogas in mcm/month
    
    # Introduce import capacity things
    @variable(model, trans_in_country[cct = 1:leng, t = 1:nmonth, ccf = 1:leng] >= 0)
    @variable(model, trans_out_country[ccf = 1:leng, t = 1:nmonth, cct = 1:leng] >= 0)
    @variable(model, import_in_month[cc = 1:leng, t = 1:nmonth] >= 0)
    @variable(model, trans_in[cc = 1:leng, t = 1:nmonth] >= 0)
    @variable(model, trans_out[cc = 1:leng, t = 1:nmonth] >= 0)
    

    # Storage variables
    @expression(model, stor_cap[cc = 1:leng], stor_df[cc,1])
    @variable(model, storage_in[cc = 1:leng, t = 1:nmonth] >= 0)
    @variable(model, storage_out[cc = 1:leng, t = 1:nmonth] >= 0)
    @variable(model, storage_fill[cc = 1:leng, t = 1:nmonth] >= 0)
    @variable(model, storage_gap[cc = 1:leng, t = 1:2] >= 0)

    # Storage Constraints
    @constraint(model, C_stor_cap[cc = 1:leng, t = 1:nmonth], storage_fill[cc,t] <= stor_cap[cc])
    @constraint(model, C_stor_cont[cc = 1:leng], storage_fill[cc,1] == init_stor_fill_prop*stor_cap[cc] + storage_in[cc,1] - storage_out[cc,1]) #53.7% full as of Jan 1 -LOOK AT THESE
    @constraint(model, C_stor_bal[cc = 1:leng, t = 2:nmonth], storage_fill[cc,t] == storage_fill[cc,t-1] + storage_in[cc,t] - storage_out[cc,t])
    #@constraint(model, stor_fill_req[cc = 1:leng], storage_fill[cc, 10] >= EU_stor_leg*stor_cap[cc]) # EU Legislation
    #@constraint(model, stor_fill_req2[cc = 1:leng], storage_fill[cc, 22] >= EU_stor_leg*stor_cap[cc])
    # Phasing in historical storage peak
    winter_1 = sum(2*demand_sector_reduc_df[cc,t,sec] for cc in 1:leng,t in 1:3, sec in 1:nsec)
    winter_2 = sum(demand_sector_reduc_df[cc, t, sec] for cc in 1:leng,t in 10:15, sec in 1:nsec)
    winter_3 = sum(2*demand_sector_reduc_df[cc, t, sec] for cc in 1:leng, t in 22:24, sec in 1:nsec)
    ratio_a = winter_2/winter_1
    ratio_b = winter_3/winter_1
    # winter_2 = sum(2*demand_sector_reduc[cc,t,sec] for cc in 1:leng, t in 10:12, sec in 1:nsec) For 1 year models
     
    @constraint(model, stor_fill_req_a[cc = 1:leng], storage_fill[cc, 10] + storage_gap[cc,1] >= ratio_a*prev_stor_peak*stor_cap[cc]) # sum of the winter months change vs historical
    @constraint(model, stor_fill_req_b[cc = 1:leng], storage_fill[cc, 22] + storage_gap[cc,2] >= ratio_b*prev_stor_peak*stor_cap[cc])
    @constraint(model, stor_fill_req_c[cc = 1:leng], storage_fill[cc, 24] >= 0.5stor_cap[cc])
    @expression(model, storage_out_tot[t = 1:nmonth], sum(storage_out[cc,t] for cc in 1:leng))
    @expression(model, storage_in_tot[t = 1:nmonth], sum(storage_in[cc,t] for cc in 1:leng))
    @constraint(model, c_max_withdraw[t = 1:nmonth], storage_out_tot[t] <= Days_per_month[t]*max_withdraw_day)
    @constraint(model, c_max_inject[t = 1:nmonth], storage_in_tot[t] <= Days_per_month[t]*max_inject_day)

    # Introduce objective variable shortfall
    @variable(model, shortfall[cc = 1:leng, t = 1:nmonth]>=0)
    @constraint(model, short_prop[cc = 1:leng, t = 1:nmonth], shortfall[cc, t] <= demand_eq[cc,t]) 

    # Monthly imports from each import source
    @variable(model, import_country[cc = 1:leng,t = 1:nmonth,rte = 1:nrte] >= 0)
    if phased_LNG== true
        import_22 = select(imports_df,Not(:LNG_2023))  #imports_df
        import_22[4,nrte] = 0.0 # baltic not ready
        import_22 = derate_imports * Matrix(import_22)
        import_22[:,3] = derate_LNG/derate_imports*import_22[:,3]
        @constraint(model, LNG_expansion_a[cc = 1:leng, t = 1:12, rte = 1:nrte], import_country[cc, t, rte] <= Days_per_month[t]*import_22[cc,rte])
        # print(import_22)
        if base_year == raw"2223"
            import_23 = select(imports_df,Not(:LNG_2022))
            #print(import_23)
            import_23 = derate_imports * Matrix(import_23)
            #print(import_23)
            import_23[:,3] = derate_LNG/derate_imports*import_23[:,3]
            @constraint(model, LNG_expansion_b[cc = 1:leng, t = 13:nmonth, rte = 1:nrte], import_country[cc, t, rte] <= Days_per_month[t]*import_23[cc,rte])
        end
    else
        imports_df = derate_imports * imports_df
        imports_df[:,3] = derate_LNG/derate_imports*imports_df[:,3]
        @constraint(model, c_import_country[cc = 1:leng, t=1:nmonth, rte = 1:nrte], import_country[cc,t,rte] <= Days_per_month[t]*imports_df[cc,rte])
    end
    
    rte_russia = nrte-1
    @constraint(model, rus_phasea[cc = 1:leng, t = 1:12], import_country[cc,t,rte_russia] <= Days_per_month[t]*rus_df[t]*import_22[cc,rte_russia])
    @constraint(model, rus_phaseb[cc = 1:leng, t = 13:nmonth], import_country[cc,t,rte_russia] <= Days_per_month[t]*rus_df[t]*import_23[cc,rte_russia]) # Russian gas phaseout
    @constraint(model, import_month[cc = 1:leng, t = 1:nmonth], import_in_month[cc,t] == sum(import_country[cc,t,rte] for rte in 1:nrte))

    @expression(model, imports_tot[cc = 1:leng, rte = 1:nrte], sum(import_country[cc,t,rte] for t in 1:nmonth))

    # Checking LNG each calendar year
    @expression(model, imports_annual1[cc = 1:leng, rte = 1:nrte], sum(import_country[cc,t,rte] for t in 1:12))
    @expression(model, imports_annual2[cc = 1:leng, rte = 1:nrte], sum(import_country[cc,t,rte] for t in 13:24))
    @expression(model, e_total_lng1, sum(imports_annual1[cc,3] for cc in 1:leng))
    @expression(model, e_total_lng2, sum(imports_annual2[cc,3] for cc in 1:leng))
    @expression(model, total_LNG, sum(imports_tot[cc,3] for cc in 1:leng))
    @constraint(model, c_total_lng1, e_total_lng1 <= LNG_market_cap)
    @constraint(model, c_total_lng2, e_total_lng2 <= LNG_market_cap)
    # @constraint(model, lng_req, sum(imports_tot[cc, 3] for cc in 1:leng) >= lng_inc*1000)

    # Monthly transmission imports
    @constraint(model, c_trans_in_country[cct = 1:leng, t=1:nmonth, ccf = 1:leng], trans_in_country[cct,t,ccf] <= derate_pipelines*Days_per_month[t]*trans_in_df[cct,ccf])
    @constraint(model, c_baltic[cct = 18, t = 1:12, ccf = 4], trans_in_country[cct,t,ccf] == 0.0)
    @constraint(model, c_trans_in_month[cct = 1:leng, t = 1:nmonth], trans_in[cct,t] == sum(trans_in_country[cct,t,ccf] for ccf in 1:leng))


    # Monthly transmission exports
    @constraint(model, c_trans_out_country[ccf = 1:leng, t=1:nmonth, cct = 1:leng], trans_out_country[ccf,t,cct] <= derate_pipelines*Days_per_month[t]*trans_out_df[ccf,cct])
    @constraint(model, c_baltic_exp[ccf = 4, t = 1:10, cct = 18], trans_out_country[ccf,t,cct] == 0.0)
    @constraint(model, c_trans_out_month[ccf = 1:leng, t = 1:nmonth], trans_out[ccf,t] == sum(trans_out_country[ccf,t,cct] for cct in 1:leng))

    # Monthly transmission matches on each side of the pipe
    @constraint(model, c_trans_in_match[cct = 1:leng, t = 1:nmonth, ccf = 1:leng], trans_in_country[cct,t,ccf] == trans_out_country[ccf, t, cct]) 
    
    # Overall gas balance for each country in each month
    @constraint(model, cGasBal[cc = 1:leng, t = 1:nmonth], shortfall[cc,t] + trans_in[cc,t] + import_in_month[cc,t] + prod_eq[cc,t] + biogas_eq[cc,t] + storage_out[cc,t]  == demand_eq[cc, t] + trans_out[cc,t] + storage_in[cc,t])


    # Objectives
    K = 10^-6
    @expression(model, shortfall_prop[cc= 1:leng, t = 1:nmonth], (1/(demand[cc,t])*shortfall[cc,t]))
    @expression(model, shortfall_prop_sum[cc = 1:leng], sum((1/nmonth)*shortfall_prop[cc,t] for t in 1:nmonth))
    @expression(model, shortfall_prop_P[cc = 1:leng], sum(P*shortfall_prop[cc,t] for t in 1:nmonth))
    #@expression(model, Eshortfall_sum_pC[cc = 1:leng], sum(P*shortfall[cc,t] for t in 1:nmonth))
    @expression(model, shortfall_sum[cc = 1:leng], sum(shortfall[cc,t] for t in 1:nmonth))
    @expression(model, tot_shortfall, sum(shortfall_sum[cc] for cc in 1:leng))
    #@expression(model, excess_sum[cc = 1:leng], sum(excess[cc,t] for t in 1:nmonth))
    #@expression(model, obj, K*total_LNG + sum(P*shortfall_prop_P[cc] for cc in 1:leng))
    @expression(model, obj,K*total_LNG + sum(P*shortfall_prop_P[cc] for cc in 1:leng) + P*tot_shortfall+ sum(P*P*shortfall_prop_P[cc] for cc in issues)) #)+ sum(P*shortfall_prop_P[cc] for cc in 1:leng)  
    @objective(model, Min, obj)

    return model, country_df
end

# Check infeasible constraints
function debugInfeas(model::Model)
    compute_conflict!(model)
    if MOI.get(model, MOI.ConflictStatus()) != MOI.CONFLICT_FOUND
        # print("No conflict could be found for an infeasible model.")
    end

    conflict_constraint_list = ConstraintRef[]
    for (F, S) in list_of_constraint_types(model)
        for con in all_constraints(model, F, S)
            if MOI.get(model, MOI.ConstraintConflictStatus(), con) == MOI.IN_CONFLICT
                push!(conflict_constraint_list, con)
                println(con)
            end
        end
    end
end

# Print important outputs to their own folders
function printout(folder::AbstractString, model::Model, country_df::DataFrame, nmonths::Int64, case::AbstractString) # Print outputs
    output = "Outputs"
    out_path = joinpath(folder, output)
    output_path = joinpath(out_path, case)
    if isdir(output_path) == false
        cd(out_path)
        mkdir(case)
        output_path = joinpath(out_path, case)
    end
    conv_mcm_bcm = 1/1000
#    filepath = joinpath(output_path, "Gas_model.lp")
#    JuMP.write_to_file(model, filepath)

    x = value.(model[:shortfall_sum])*conv_mcm_bcm
    r = value.(model[:shortfall_prop_sum])
    country_df[!, "Shortfall"] = x
    country_df[!, "Shortfall/Demand"] = r
    z = value.(model[:storage_fill])*conv_mcm_bcm
    m = value.(model[:shortfall])*conv_mcm_bcm
    storage_out_df = DataFrame(z,:auto)
    sf_month_df = DataFrame(m, :auto)
    storage_out_df.Country = country_df[!, :Country]
    sf_month_df.Country = country_df[!, :Country]
    sf_month = "Shortfall_month.csv"
    sf_month_path = joinpath(output_path, sf_month)
    shortfall_csv = "Shortfall.csv"
    shortfall_path = joinpath(output_path, shortfall_csv)
    storage_output = "Storage_out.csv"
    stor_out_path = joinpath(output_path, storage_output)

    import_sources = [:Cap_Al, :Algeria, :LNG,  :Libya, :Norway, :Turkey, :Russia, :Baltic]
    imports_out = value.(model[:imports_tot])*conv_mcm_bcm
    #println(imports_out)
    imports_out_df = DataFrame(imports_out, import_sources)#
    imports_out_df.Country = country_df[:, :Country]

    import_country_out = value.(model[:import_country])*conv_mcm_bcm
    for i in 1:nmonths
        imports_month_df = DataFrame(import_country_out[:,i,:], import_sources)#
        imports_month_df.Country = country_df[:, :Country]
        month_path = "ImportsMonth"*string(i)*".csv"
        tot_path = joinpath(output_path, month_path)
        CSV.write(tot_path, imports_month_df)
    end

    demand_out = value.(model[:demand_eq])
    demand_outdf = DataFrame(demand_out, :auto)
    demand_outdf.Country = country_df[:,:Country]
    demandcsv = "Demand.csv"
    demand_outpath = joinpath(output_path, demandcsv)
    CSV.write(demand_outpath, demand_outdf)

    imports_out_csv = "Imports_out.csv"
    imports_out_path = joinpath(output_path, imports_out_csv)

    CSV.write(imports_out_path, imports_out_df)
    CSV.write(stor_out_path, storage_out_df)
    CSV.write(shortfall_path, country_df)
    CSV.write(sf_month_path, sf_month_df)

    # Look to include a function here that prints out every month of imports - would be good to see how the phase out actually happens

end

# Transpose Dataframe helper function
function dftranspose(df::DataFrame, withhead::Bool)
	if withhead
		colnames = cat(:Row, Symbol.(df[!,1]), dims=1)
		return DataFrame([[names(df)]; collect.(eachrow(df))], colnames)
	else
		return DataFrame([[names(df)]; collect.(eachrow(df))], [:Row; Symbol.("x",axes(df, 1))])
	end
end # End dftranpose()

# Transposes dataframes
function transposer(df::DataFrame) # transposes and removes country names
    t = dftranspose(df, false)
    select!(t, Not(:1))
    return t
end

# Select whether or not to use lower heating demand reduction assumptions
function parse_chp_level(name::AbstractString)
    mild = "MildCHP"
    low_chp = occursin(mild, name)
    return low_chp
end

# Get the name of a csv file without the .csv
function removecsv(name::AbstractString)
    name = split(name, ".")
    return name[1]
end
"""
function test_ratios(demand_df::AbstractDataFrame, sector_df::AbstractDataFrame, prod_df::AbstractDataFrame, post_path::AbstractString)
    elec_path = joinpath(post_path, m)
    case = removecsv(m)
    println("Running case: "*case)
    low_chp = parse_chp_level(case) # be sure to match to inputs  Note: Low heat true = lower reduction - 4% reduction for all heating loads
    sec_reduc_df = check_heating(input_path, low_chp)
    elec_df = CSV.read(elec_path, header=1, DataFrame)

    demand_sector_reduc_df = demand_builder(sec_reduc_df, sector_df, demand_df, elec_df, prod_df)
    ratio_a, ratio_b = storage_ratios(demand_sector_reduc_df, demand_df)
end
"""

function runner(input_path::AbstractString, post_path::AbstractString, m::AbstractString, folder::AbstractString, stor_df::AbstractDataFrame, prod_df::AbstractDataFrame, demand_df::AbstractDataFrame, trans_in_df::AbstractDataFrame, trans_out_df::AbstractDataFrame, imports_df::AbstractDataFrame, country_df::AbstractDataFrame, sector_df::AbstractDataFrame, biogas_df::AbstractDataFrame)
    # Get paths
    elec_path = joinpath(post_path, m)

    # Get inputs
    nmonths = ncol(demand_df)
    case = removecsv(m)
    println("Running case: "*case)
    low_chp = parse_chp_level(case) # be sure to match to inputs  Note: Low heat true = lower reduction - 4% reduction for all heating loads
    sec_reduc_df = check_heating(input_path, low_chp)
    elec_df = CSV.read(elec_path, header=1, DataFrame)

    demand_sector_reduc_df = demand_builder(sec_reduc_df, sector_df, demand_df, elec_df, prod_df)
    # ratio_a, ratio_b = storage_ratios(demand_sector_reduc_df, demand_df)

    # Create Model
    model = Model(CPLEX.Optimizer)
    model, country_df = initialize_model!(model, demand_sector_reduc_df, stor_df, prod_df, demand_df, trans_in_df, trans_out_df, imports_df, country_df, sector_df, biogas_df) #, ratio_a, ratio_b

    # Solve
    optimize!(model)
    # Print if feasible
    compute_conflict!(model)
    if MOI.get(model, MOI.ConflictStatus()) != MOI.CONFLICT_FOUND
        # print("No conflict could be found for an infeasible model.")
        printout(folder, model, country_df, nmonths, case)
        tot_LNG = 0.001*value(model[:total_LNG])
        tot_gas = 0.001*value(model[:demand_tot])
        tot_shortfall = 0.001*value(model[:tot_shortfall])
        return tot_LNG, tot_gas, tot_shortfall
    else
        conflict_constraint_list = ConstraintRef[]
        for (F, S) in list_of_constraint_types(model)
            for con in all_constraints(model, F, S)
                if MOI.get(model, MOI.ConstraintConflictStatus(), con) == MOI.IN_CONFLICT
                    push!(conflict_constraint_list, con)
                    println(con)
                end
            end
        end
        return 999, 999, 999
    end
end

function demand_builder(sec_reduc_df::AbstractDataFrame, sector_df::AbstractDataFrame, demand_df::AbstractDataFrame, elec_df::AbstractDataFrame, prod_df::AbstractDataFrame)
    leng = nrow(sector_df)
    nmonth = ncol(demand_df)
    nsec = ncol(sector_df)
    reduc_end = 5

    demand_sector_reduc_df = Array{Float64, 3}(undef, (leng, nmonth, nsec))
    ire_demand_tot = zeros(nmonth)
    for sec in 1:nsec
        for t in 1:nmonth
            for cc in 1:leng
                if sec == 1 && t <= reduc_end
                    demand_sector_reduc_df[cc,t,sec] = sec_reduc_df[t,sec]*sector_df[cc,sec]*demand_df[cc,t]
                elseif sec == 1 && t > reduc_end
                    demand_sector_reduc_df[cc,t,sec] = elec_df[cc,t]*sector_df[cc,sec]*demand_df[cc,t]
                elseif sec >= 2
                    demand_sector_reduc_df[cc,t,sec] = sec_reduc_df[t,sec]*sector_df[cc,sec]*demand_df[cc,t]
                end
            end
        end
    end

    # println(demand_sector_reduc_df[:,:,1])

    return demand_sector_reduc_df
end

function main()
    folder = "C:\\Users\\mike_\\Documents\\ZeroLab\\EU_Gas_Model"
    input = "Inputs"
    input_path = joinpath(folder, input)
    post = "Post_NoWinter"
    post_path = joinpath(input_path, post)
    outputs = "Outputs"
    lngcsv = "plotting_allcases.csv"
    outpath = joinpath(folder, outputs, lngcsv)
    

    # Get set of input scenarios
    elec_files = readdir(post_path, join = false)

    # initialize dfs
    stor_df, prod_df, demand_df, trans_in_df, trans_out_df, imports_df, country_df, sector_df, biogas_df = initialize_data(folder)

    # Run cases
    counter = 0
    lng_cases = zeros(length(elec_files))
    aggregate_demand = zeros(length(elec_files))
    ag_short = zeros(length(elec_files))
    names = Array{AbstractString,1}(undef, length(elec_files))
    for m in elec_files
        counter = counter + 1
        lng_cases[counter], aggregate_demand[counter], ag_short[counter] = runner(input_path, post_path, m, folder, stor_df, prod_df, demand_df, trans_in_df, trans_out_df, imports_df, country_df, sector_df, biogas_df)
        names[counter] = removecsv(m)
    end
    plotting_df = DataFrame(Case=names, LNG=lng_cases, Demand=aggregate_demand, Shortfall=ag_short)
    CSV.write(outpath, plotting_df)
end

main()