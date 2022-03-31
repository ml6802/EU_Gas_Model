using JuMP, CPLEX, Ipopt
using CSV
using DataFrames
using DelimitedFiles

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
    rus = "RussiaReduc.csv"
    sec_reduc = "SectoralReduction.csv"

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

    rus_path = joinpath(input_path, rus)
    rus_df = CSV.read(rus_path, header=1, DataFrame)

    sec_reduc_path = joinpath(input_path, sec_reduc)
    sec_reduc_df = CSV.read(sec_reduc_path, header=1, DataFrame)

    check_LNG_year!(imports_df, LNG_year)
    check_stor_year!(stor_df, stor_year)

    return stor_df, prod_df, demand_df, trans_in_df, trans_out_df, imports_df, country_df, sector_df, rus_df, sec_reduc_df
end

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
        select!(imports_df, Not(:Baltic))
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

function initialize_model!(model::Model, folder::AbstractString)
    # initialize dfs
    stor_df, prod_df, demand_df, trans_in_df, trans_out_df, imports_df, country_df, sector_df, rus_df, sec_reduc_df = initialize_data(folder)
    # Introduce all countries demand
    leng = nrow(demand_df)
    nmonth = ncol(demand_df) # Make sure everything has same number of countries, months, and sectors
    nsec = ncol(sector_df)
    P = 10^5
    phased_LNG = true
    nrte = ncol(imports_df) - 1
    Days_per_month = [31,28,31,30,31,30,31,31,30,31,30,31,31,28,31,30,31,30,31,31,30,31,30,31]
    rus_df = [1,1,0.8,0.7,0.6,0.5,0.4,0.3,0.1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    # EU_tot_sec = [.15, .171, .254, .117, .308] # change to average of demand_df
    max_withdraw_day = 2022.401074
    max_inject_day = 1164.765988
    init_stor_fill_prop = 0.537
    # EU_stor_leg = 0.9
    prev_stor_peak = 0.77
    println(sector_df)
    println(sec_reduc_df)


    # Setting demands and production up - equality to start with
    @expression(model, demand_sector[cc = 1:leng, t = 1:nmonth, sec = 1:nsec], sector_df[cc,sec]*demand_df[cc,t])
    @expression(model, demand_sector_reduc[cc = 1:leng, t = 1:nmonth, sec = 1:nsec], sec_reduc_df[t,sec]*demand_sector[cc,t,sec])
    @expression(model, demand_eq[cc = 1:leng, t = 1:nmonth], sum(demand_sector_reduc[cc,t,sec] for sec in 1:nsec))
    demand_tot = sum(demand_eq[cc,t] for t in 1:nmonth, cc in 1:leng)
    print(demand_tot)
#    @expression(model, demand_eq[cc = 1:leng, t = 1:nmonth], 0.802*demand_df[cc, t])
    @expression(model, prod_eq[cc = 1:leng, t = 1:nmonth], prod_df[cc,t])
    
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

    # Storage Constraints
    @constraint(model, C_stor_cap[cc = 1:leng, t = 1:nmonth], storage_fill[cc,t] <= stor_cap[cc])
    @constraint(model, C_stor_cont[cc = 1:leng], storage_fill[cc,1] == init_stor_fill_prop*stor_cap[cc] + storage_in[cc,1] - storage_out[cc,1]) #53.7% full as of Jan 1 -LOOK AT THESE
    @constraint(model, C_stor_bal[cc = 1:leng, t = 2:nmonth], storage_fill[cc,t] == storage_fill[cc,t-1] + storage_in[cc,t] - storage_out[cc,t])
    #@constraint(model, stor_fill_req[cc = 1:leng], storage_fill[cc, 10] >= EU_stor_leg*stor_cap[cc]) # EU Legislation
    # Phasing in historical storage peak
    winter_1 = sum(2*demand_sector_reduc[cc,t,sec] for cc in 1:leng, t in 1:3, sec in 1:nsec)
    winter_2 = sum(demand_sector_reduc[cc,t,sec] for cc in 1:leng, t in 10:15, sec in 1:nsec)
    winter_3 = sum(2*demand_sector_reduc[cc,t,sec] for cc in 1:leng, t in 21:24, sec in 1:nsec)
    ratio_a = winter_2/winter_1
    ratio_b = winter_3/winter_1
    @constraint(model, stor_fill_req_a[cc = 1:leng], storage_fill[cc, 10] >= ratio_a*prev_stor_peak*stor_cap[cc]) # sum of the winter months change vs historical
    @constraint(model, stor_fill_req_b[cc = 1:leng], storage_fill[cc, 22] >= ratio_b*prev_stor_peak*stor_cap[cc])
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
        import_22 = select(imports_df,Not(:LNG_2023))
        import_22[4,nrte] = 0.0 # baltic not ready
        @constraint(model, LNG_expansion_a[cc = 1:leng, t = 1:12, rte = 1:nrte], import_country[cc, t, rte] <= Days_per_month[t]*import_22[cc,rte])
        print(import_22)
        import_23 = select(imports_df,Not(:LNG_2022))
        print(import_23)
        @constraint(model, LNG_expansion_b[cc = 1:leng, t = 13:nmonth, rte = 1:nrte], import_country[cc, t, rte] <= Days_per_month[t]*import_23[cc,rte])
    else
        @constraint(model, c_import_country[cc = 1:leng, t=1:nmonth, rte = 1:nrte], import_country[cc,t,rte] <= Days_per_month[t]*imports_df[cc,rte])
    end
    
    rte_russia = nrte-1
    @constraint(model, rus_phase[cc = 1:leng, t = 1:nmonth], import_country[cc,t,rte_russia] <= Days_per_month[t]*rus_df[t]*import_23[cc,rte_russia]) # Russian gas phaseout
    @constraint(model, import_month[cc = 1:leng, t = 1:nmonth], import_in_month[cc,t] == sum(import_country[cc,t,rte] for rte in 1:nrte))

    @expression(model, imports_tot[cc = 1:leng, rte = 1:nrte], sum(import_country[cc,t,rte] for t in 1:nmonth))

    # Monthly transmission imports
    @constraint(model, c_trans_in_country[cct = 1:leng, t=1:nmonth, ccf = 1:leng], trans_in_country[cct,t,ccf] <= Days_per_month[t]*trans_in_df[cct,ccf])
    @constraint(model, c_baltic[cct = 18, t = 1:12, ccf = 4], trans_in_country[cct,t,ccf] == 0.0)
    @constraint(model, c_trans_in_month[cct = 1:leng, t = 1:nmonth], trans_in[cct,t] == sum(trans_in_country[cct,t,ccf] for ccf in 1:leng))


    # Monthly transmission exports
    @constraint(model, c_trans_out_country[ccf = 1:leng, t=1:nmonth, cct = 1:leng], trans_out_country[ccf,t,cct] <= Days_per_month[t]*trans_out_df[ccf,cct])
    @constraint(model, c_baltic_exp[ccf = 4, t = 1:12, cct = 18], trans_out_country[ccf,t,cct] == 0.0)
    @constraint(model, c_trans_out_month[ccf = 1:leng, t = 1:nmonth], trans_out[ccf,t] == sum(trans_out_country[ccf,t,cct] for cct in 1:leng))

    # Monthly transmission matches on each side of the pipe
    @constraint(model, c_trans_in_match[cct = 1:leng, t = 1:nmonth, ccf = 1:leng], trans_in_country[cct,t,ccf] == trans_out_country[ccf, t, cct]) 
    
    # Overall gas balance for each country in each month
    @constraint(model, cGasBal[cc = 1:leng, t = 1:nmonth], shortfall[cc,t] + trans_in[cc,t] + import_in_month[cc,t] + prod_eq[cc,t] + storage_out[cc,t]  == demand_eq[cc, t] + trans_out[cc,t] + storage_in[cc,t])


    # Objectives
    @expression(model, shortfall_prop[cc= 1:leng, t = 1:nmonth], (1/(demand_eq[cc,t])*shortfall[cc,t]))
    @expression(model, shortfall_prop_sum[cc = 1:leng], sum((1/nmonth)*shortfall_prop[cc,t] for t in 1:nmonth))
    @expression(model, shortfall_prop_P[cc = 1:leng], sum(P*shortfall_prop[cc,t] for t in 1:nmonth))
    #@expression(model, Eshortfall_sum_pC[cc = 1:leng], sum(P*shortfall[cc,t] for t in 1:nmonth))
    @expression(model, shortfall_sum[cc = 1:leng], sum(shortfall[cc,t] for t in 1:nmonth))
    #@expression(model, excess_sum[cc = 1:leng], sum(excess[cc,t] for t in 1:nmonth))
    @expression(model, obj, sum(P*shortfall_prop_P[cc] for cc in 1:leng))
    @objective(model, Min, obj)

    return model, country_df
end

function debugInfeas(model::Model)
    compute_conflict!(model)
    if MOI.get(model, MOI.ConflictStatus()) != MOI.CONFLICT_FOUND
        print("No conflict could be found for an infeasible model.")
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

function printout(folder::AbstractString, model::Model, country_df::DataFrame, nmonths::Int64) # Print outputs
    output = "Outputs"
    output_path = joinpath(folder, output)
    conv_mcm_bcm = 1/1000
    filepath = joinpath(output_path, "Gas_model.lp")
    JuMP.write_to_file(model, filepath)

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

    import_sources = [:Cap_Al, :Algeria, :LNG, :Libya, :Norway, :Turkey, :Russia, :Baltic]
    imports_out = value.(model[:imports_tot])*conv_mcm_bcm
    imports_out_df = DataFrame(imports_out, import_sources)
    imports_out_df.Country = country_df[!, :Country]

    import_country_out = value.(model[:import_country])*conv_mcm_bcm
    for i in 1:nmonths
        imports_month_df = DataFrame(import_country_out[:,i,:], import_sources)
        imports_month_df.Country = country_df[!, :Country]
        month_path = "ImportsMonth"*string(i)*".csv"
        tot_path = joinpath(output_path, month_path)
        CSV.write(tot_path, imports_month_df)
    end

    imports_out_csv = "Imports_out.csv"
    imports_out_path = joinpath(output_path, imports_out_csv)

    CSV.write(imports_out_path, imports_out_df)
    CSV.write(stor_out_path, storage_out_df)
    CSV.write(shortfall_path, country_df)
    CSV.write(sf_month_path, sf_month_df)

    # Look to include a function here that prints out every month of imports - would be good to see how the phase out actually happens

end

function dftranspose(df::DataFrame, withhead::Bool)
	if withhead
		colnames = cat(:Row, Symbol.(df[!,1]), dims=1)
		return DataFrame([[names(df)]; collect.(eachrow(df))], colnames)
	else
		return DataFrame([[names(df)]; collect.(eachrow(df))], [:Row; Symbol.("x",axes(df, 1))])
	end
end # End dftranpose()

function transposer(df::DataFrame) # transposes and removes country names
    t = dftranspose(df, false)
    select!(t, Not(:1))
    return t
end

function main()
    folder = "C:\\Users\\mike_\\Documents\\ZeroLab\\EU_Gas_Model"
    conv_mcm_bcm = 1/1000
    nmonths = 24

    # Creating model
    model = Model(CPLEX.Optimizer)
    model, country_df = initialize_model!(model, folder)

    # Solve
    optimize!(model)

    debugInfeas(model)

    #@show value.(model[:demand_sector])/1000
    @show value.(model[:shortfall_sum])*conv_mcm_bcm
    @show sum(value.(model[:shortfall_sum]))*conv_mcm_bcm
    @show sum(value.(model[:imports_tot]))*conv_mcm_bcm
    @show value.(model[:shortfall_prop_sum])

    printout(folder, model, country_df, nmonths)
end

main()