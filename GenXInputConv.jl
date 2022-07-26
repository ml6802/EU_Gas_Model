using CSV, DelimitedFiles, DataFrames

Post_path2022() = "C:\\Users\\mike_\\Downloads\\Post_2223_Hydro_Nuk_FIXED"
Post_path2023() = "C:\\Users\\mike_\\Downloads\\Post_2324_Hydro_Nuk_FIXED"
Output_path() = "C:\\Users\\mike_\\Documents\\ZeroLab\\EU_Gas_Model\\Inputs\\Post_AHNFixed"
CSVdf(path::AbstractString) = CSV.read(path, header = 1, DataFrame)
dfCSV(path::AbstractString, df::DataFrame) = CSV.write(path, df)

function reformat_cols1(df::DataFrame)
    accel = false
    if accel == true
        select!(df, Not(:Month_13))
        select!(df, Not(:Month_14))
        select!(df, Not(:Month_15))
        select!(df, Not(:Month_16))
        select!(df, Not(:Month_17))
        select!(df, Not(:Month_18))
        select!(df, Not(:Month_19))
        select!(df, Not(:Month_20))
        select!(df, Not(:Month_21))
        select!(df, Not(:Month_22))
        select!(df, Not(:Month_23))
        select!(df, Not(:Month_24))
    end
    # Select Correct Cols
    select!(df, Not(:zone))
    select!(df, Not(:Percent_e))
    return df
end

function reformat_cols2(df::DataFrame)
    accel = false
    if accel == true
        select!(df, Not(:Month_1))
        select!(df, Not(:Month_2))
        select!(df, Not(:Month_3))
        select!(df, Not(:Month_4))
        select!(df, Not(:Month_5))
        select!(df, Not(:Month_6))
        select!(df, Not(:Month_7))
        select!(df, Not(:Month_8))
        select!(df, Not(:Month_9))
        select!(df, Not(:Month_10))
        select!(df, Not(:Month_11))
        select!(df, Not(:Month_12))
    end
        namesdf2 = [:Name, :Month_13, :Month_14,:Month_15,:Month_16,:Month_17,:Month_18,:Month_19,:Month_20,:Month_21, :Month_22, :Month_23, :Month_24]
        # Select Correct Cols
        select!(df, Not(:zone))
        select!(df, Not(:Percent_e))
        df = rename(df, namesdf2)
        return df
end

function cut_cols(df::DataFrame)
    # Select Correct Cols
    select!(df, Not(:zone))
    select!(df, Not(:Percent_e))
    select!(df, Not(:Name))
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
    select!(df, Not(:Name))
    countries_out = [4,10,12,13,14,18,21,25,26,27]
    values = zeros(24)
    for i in countries_out
        insert!.(eachcol(df), i, values)
    end
    return df
end


function main()
    path1 = Post_path2022()
    path2 = Post_path2023()
    list_inputs1 = readdir(path1, join=false)
    list_inputs2 = readdir(path2, join=false)
    for file1 in list_inputs1
        file1path = joinpath(path1,file1)
        df1 = CSVdf(file1path)
        df1 = move_ireland(df1)
        df1 = reformat_cols1(df1) # For future should swap order of this and next, but doesn't matter now
        for file2 in list_inputs2
            if file1 == file2
                file2path = joinpath(path2,file2)
                df2 = CSVdf(file2path)
                df2 = move_ireland(df2)
                df2 = reformat_cols2(df2) # For future should swap order of this and next, but doesn't matter now
                leftjoin!(df1,df2,on = :Name)
                df1 = add_countries(df1)
                output_path = joinpath(Output_path(),file1)
                dfCSV(output_path,df1)
            end
        end
    end

end

main()