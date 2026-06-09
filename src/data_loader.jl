function parse_items(line::AbstractString)::Vector{String}
    clean_line = strip(line)
    isempty(clean_line) && return String[]

    if occursin("{", clean_line) && occursin("}", clean_line)
        start_idx = findfirst('{', clean_line)
        end_idx = findlast('}', clean_line)
        clean_line = clean_line[nextind(clean_line, start_idx):prevind(clean_line, end_idx)]
    end

    if occursin(",", clean_line)
        return [strip(item) for item in split(clean_line, ",") if !isempty(strip(item))]
    end

    return String.(split(clean_line))
end

function load_transactions(loader::DataLoader)::Dict{String, Transaction}
    if !isempty(loader.transactions)
        return loader.transactions
    end

    transaction_idx = 1
    open(loader.file_path, "r") do io
        for line in eachline(io)
            items = parse_items(line)
            isempty(items) && continue

            loader.transactions["t$(transaction_idx)"] = Transaction(items)
            transaction_idx += 1
        end
    end

    return loader.transactions
end

load_transactions(file_path::AbstractString)::Dict{String, Transaction} =
    load_transactions(DataLoader(file_path))

function load_unique_items(loader::DataLoader)::Set{String}
    transactions = load_transactions(loader)
    unique_items = Set{String}()

    for transaction in values(transactions)
        union!(unique_items, transaction.items)
    end

    return unique_items
end
