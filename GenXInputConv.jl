using CSV, DelimitedFiles, DataFrames

Post_path() = "C:\\Users\\mike_\\Documents\\ZeroLab\\EU_Gas_Model\\Inputs\\Post_Final_v3"
CSVdf(path::AbstractString) = CSV.read(path, header = 1, DataFrame)
dfCSV(path::AbstractString, df::DataFrame) = CSV.write(path, df)

function reformat_cols(df::DataFrame)
    namesdf2 = [:Name, :Month_13, :Month_14,:Month_15,:Month_16,:Month_17,:Month_18,:Month_19,:Month_20,:Month_21, :Month_22, :Month_23, :Month_24]
    namesdf3 = [:Name, :Month_25, :Month_26, :Month_27]
    # Select Correct Cols
    select!(df, Not(:zone))
    select!(df, Not(:Percent_e))
    # Loop months to match 24 month profile
    df2 = copy(df)
    df2 = rename(df2, namesdf2)
    df3 = copy(df)
    select!(df3,:Name, :Month_1, :Month_2, :Month_3)
    df3 = rename(df3, namesdf3)
    df = leftjoin(df,df2,on = :Name)
    df = leftjoin(df, df3, on = :Name)
    select!(df, Not(:Name))
    select!(df, Not(:Month_1))
    select!(df, Not(:Month_2))
    select!(df, Not(:Month_3))
    return df
end

function move_ireland(df::DataFrame)
    df_ireland = filter(row -> row.Name == "Ireland",df)
    deleteat!(df, 6)
    append!(df, df_ireland)
    println(df)
    return df
end

function add_countries(df::DataFrame)
    countries_out = [4,10,12,13,14,18,21,25,26,27,28]
    values = zeros(24)
    for i in countries_out
        insert!.(eachcol(df), i, values)
    end
    return df
end

function main()
    path = Post_path()
    list_inputs = readdir(path, join=true)
    for file in list_inputs
        df = CSVdf(file)
        df = move_ireland(df)
        df = reformat_cols(df) # For future should swap order of this and next, but doesn't matter now
        df = add_countries(df)
        dfCSV(file,df)
    end
end

main()