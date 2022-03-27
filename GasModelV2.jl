using JuMP, CPLEX, Ipopt
using CSV
using DataFrames
using DelimitedFiles

# Reading in CSVs
function initialize_data(folder::AbstractString)
    Base_year = raw"21" # Just keep the last two digits of the year name - 19, 20, or 21
    imports = "ImportCaps.csv"
    trans = "TransmissionCap.csv"
    input = "Inputs"
    input_path = joinpath(folder, input)
    demand = "Demand"*Base_year*".csv"
    production = "Production"*Base_year*".csv"
    storage = "Storage.csv"
    countrylist = "CountryList.csv"
    LNG_year = raw"30" # Options - 21, 22, 25, 30
    stor_year = raw"22" # Options - 22, 25, 30


    country_path = joinpath(input_path, countrylist)
    country_df = CSV.read(country_path, header = 1, DataFrame)

    imp_path = joinpath(input_path, imports)
    imports_df = CSV.read(imp_path, header=1, DataFrame)

    trans_path = joinpath(input_path, trans)
    trans_in_df = CSV.read(trans_path, header=1, DataFrame) # in mcm per day - col is country from, row is country to
    print(trans_in_df)
    trans_out_df = transposer(trans_in_df)
    print(trans_out_df)

    demand_path = joinpath(input_path, demand)
    demand_df = CSV.read(demand_path, header=1, DataFrame)

    prod_path = joinpath(input_path, production)
    prod_df = CSV.read(prod_path, header=1, DataFrame)

    stor_path = joinpath(input_path, storage)
    stor_df = CSV.read(stor_path, header=1, DataFrame)

    # Check LNG year
    if LNG_year == raw"21"
        select!(imports_df, Not(:LNG_2022))
        select!(imports_df, Not(:LNG_2025))
        select!(imports_df, Not(:LNG_2030))
    elseif LNG_year == raw"22"
        select!(imports_df, Not(:LNG_2021))
        select!(imports_df, Not(:LNG_2025))
        select!(imports_df, Not(:LNG_2030))
    elseif LNG_year == raw"25"
        select!(imports_df, Not(:LNG_2021))
        select!(imports_df, Not(:LNG_2022))
        select!(imports_df, Not(:LNG_2030))
    elseif LNG_year == raw"30"
        select!(imports_df, Not(:LNG_2021))
        select!(imports_df, Not(:LNG_2022))
        select!(imports_df, Not(:LNG_2025))
    end



    #Check Storage year
    if stor_year == raw"22"
        select!(stor_df, :1)
    elseif stor_year == raw"25"
        select!(stor_df, :2)
    elseif stor_year == raw"30"
        select!(stor_df, :3)
    end
    return stor_df, prod_df, demand_df, trans_in_df, trans_out_df, imports_df, country_df
end   

function initialize_model!(model::Model, folder::AbstractString, demand_reduc::Float64)
    # initialize dfs
    stor_df, prod_df, demand_df, trans_in_df, trans_out_df, imports_df, country_df = initialize_data(folder)
    # Introduce all countries demand
    leng = nrow(demand_df)
    nmonth = 12
    P = 10^10
    Days_per_month = [31,28,31,30,31,30,31,31,30,31,30,31]
    max_withdraw_day = 2022.401074
    max_inject_day = 1164.765988

    # Setting demands and production up - equality to start with
    @expression(model, demand_eq[cc = 1:leng, t = 1:nmonth], demand_reduc*demand_df[cc,t])
    @expression(model, prod_eq[cc = 1:leng, t = 1:nmonth], prod_df[cc,t])
    
    # Introduce import capacity things
    @variable(model, import_country[cc = 1:leng,t = 1:nmonth,rte = 1:6] >= 0)
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
    @variable(model, storage_fill_prev[cc = 1:leng, t = 1:(nmonth+1)] >= 0)

    # Storage Constraints
    @constraint(model, C_stor_cap[cc = 1:leng, t = 1:nmonth], storage_fill[cc,t] <= stor_cap[cc])
    @constraint(model, C_stor_init[cc = 1:leng], storage_fill_prev[cc,1] == .537stor_cap[cc]) #53.7% full as of Jan 1
    @constraint(model, C_stor_cont[cc = 1:leng, t = 1:nmonth], storage_fill_prev[cc, t+1] == storage_fill[cc, t])
    @constraint(model, C_stor_bal[cc = 1:leng, t = 1:nmonth], storage_fill[cc,t] == storage_fill_prev[cc,t] + storage_in[cc,t] - storage_out[cc,t])
    @constraint(model, stor_fill_req[cc = 1:leng], storage_fill[cc, 10] >= 0.9stor_cap[cc]) # EU Legislation
    #@constraint(model, stor_fill_req[cc = 1:leng], storage_fill[cc, 10] >= demand_reduc*.77stor_cap[cc])

    @expression(model, storage_out_tot[t = 1:nmonth], sum(storage_out[cc,t] for cc in 1:leng))
    @expression(model, storage_in_tot[t = 1:nmonth], sum(storage_in[cc,t] for cc in 1:leng))
    @constraint(model, c_max_withdraw[t = 1:nmonth], storage_out_tot[t] <= Days_per_month[t]*max_withdraw_day)
    @constraint(model, c_max_inject[t = 1:nmonth], storage_in_tot[t] <= Days_per_month[t]*max_inject_day)

    # Introduce objective variable shortfall + excess
    @variable(model, shortfall[cc = 1:leng, t = 1:nmonth]>=0)
    @variable(model, excess[cc = 1:leng, t = 1:nmonth]>=0)
    @constraint(model, shortfall_c[cc = 1:leng, t = 1:nmonth], shortfall[cc,t] <= demand_eq[cc,t])

    # Overall gas balance for each country in each month
    @constraint(model, cGasBal[cc = 1:leng, t = 1:nmonth], shortfall[cc,t] + trans_in[cc,t] + import_in_month[cc,t] + prod_eq[cc,t] + storage_out[cc,t]  == demand_eq[cc, t] + trans_out[cc,t] + excess[cc,t] + storage_in[cc,t])

    # Monthly imports from each import source
    @constraint(model, c_import_country[cc = 1:leng, t=1:nmonth, rte = 1:6], import_country[cc,t,rte] <= Days_per_month[t]*imports_df[cc,rte])
    @constraint(model, import_month[cc = 1:leng, t = 1:nmonth], import_in_month[cc,t] == sum(import_country[cc,t,rte] for rte in 1:6))

    @variable(model, imports_tot[cc = 1:leng, rte = 1:6])
    @constraint(model, import_adder[cc = 1:leng, rte = 1:6], imports_tot[cc, rte] == sum(import_country[cc,t,rte] for t in 1:nmonth))

    # Monthly transmission imports - look at this

    @constraint(model, c_trans_in_country[cct = 1:leng, t=1:nmonth, ccf = 1:leng], trans_in_country[cct,t,ccf] <= Days_per_month[t]*trans_in_df[cct,ccf])
    @constraint(model, c_trans_in_month[cct = 1:leng, t = 1:nmonth], trans_in[cct,t] == sum(trans_in_country[cct,t,ccf] for ccf in 1:leng))

    # Monthly transmission exports - look at this
    @constraint(model, c_trans_out_country[ccf = 1:leng, t=1:nmonth, cct = 1:leng], trans_out_country[ccf,t,cct] <= Days_per_month[t]*trans_out_df[ccf,cct])
    @constraint(model, c_trans_out_month[ccf = 1:leng, t = 1:nmonth], trans_out[ccf,t] == sum(trans_out_country[ccf,t,cct] for cct in 1:leng))

    # Monthly transmission matches on each side of the pipe
    @constraint(model, c_trans_in_match[cct = 1:leng, t = 1:nmonth, ccf = 1:leng], trans_in_country[cct,t,ccf] == trans_out_country[ccf, t, cct]) 
    
    # Objectives
    @expression(model, Eshortfall_sum_pC[cc = 1:leng], sum(P*shortfall[cc,t] for t in 1:nmonth))
    @expression(model, shortfall_sum[cc = 1:leng], sum(shortfall[cc,t] for t in 1:nmonth))
    @expression(model, Eshortfall_total, sum(Eshortfall_sum_pC[cc] for cc in 1:leng))
    @expression(model, excess_tot[cc = 1:leng], sum(excess[cc,t] for t in 1:nmonth))
    @expression(model, obj, sum(excess_tot[cc] + Eshortfall_sum_pC[cc] for cc in 1:leng))
    @objective(model, Min, obj)

    return model, country_df
end

function printout(folder::AbstractString, model::Model, country_df::DataFrame) # Print outputs
    output = "Outputs"
    output_path = joinpath(folder, output)

    x = value.(model[:shortfall_sum])/1000
    y = value.(model[:excess_tot])/1000
    country_df[!, "Shortfall"] = x
    country_df[!, "Excess"] = y
    z = value.(model[:storage_fill])/1000
    m = value.(model[:shortfall])/1000
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

    import_sources = [:Cap_Al, :Algeria, :LNG, :Libya, :Norway, :Turkey]
    imports_out = value.(model[:imports_tot])/1000
    imports_out_df = DataFrame(imports_out, import_sources)
    imports_out_df.Country = country_df[!, :Country]

    imports_out_csv = "Imports_out.csv"
    imports_out_path = joinpath(output_path, imports_out_csv)

    CSV.write(imports_out_path, imports_out_df)
    CSV.write(stor_out_path, storage_out_df)
    CSV.write(shortfall_path, country_df)
    CSV.write(sf_month_path, sf_month_df)
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
    demand_reduc = 0.802
    folder = "C:\\Users\\mike_\\Documents\\ZeroLab\\EU_Gas_Model"

    # Creating model
    model = Model(CPLEX.Optimizer)
    model, country_df = initialize_model!(model, folder, demand_reduc)

    # Solve
    optimize!(model)

    @show value.(model[:shortfall_sum])/1000
    @show sum(value.(model[:shortfall_sum])/1000)
    @show sum(value.(model[:imports_tot]))/1000

    printout(folder, model, country_df)
end

main()