using ..GetDP: add_raw_code, comment, make_args

"""
    QuantityTerm

A term or integral in a post-processing quantity.
"""
mutable struct QuantityTerm
    term_type::String  # "Term", "Integral", "Local", etc.
    Value::String
    options::Dict
    comment::Union{String, Nothing}

    function QuantityTerm(; term_type, Value, comment = nothing, kwargs...)
        new(term_type, Value, Dict(kwargs), comment)
    end
end

function code(term::QuantityTerm)
    code_lines = String[]
    # Common keys to iterate over
    option_keys = [:In, :Jacobian, :Integration]

    if term.term_type == "Term"
        # Include Type option (e.g., Global) if specified
        type_str = haskey(term.options, :Type) ? "Type $(term.options[:Type]); " : ""
        push!(code_lines, "Term { $type_str[ $(term.Value) ];")
        for key in option_keys
            if haskey(term.options, key)
                push!(code_lines, "    $key $(make_args(term.options[key], sep=","));")
            end
        end
        push!(code_lines, "}")

    elseif term.term_type == "Integral"
        push!(code_lines, "Integral { [ $(term.Value) ];")
        for key in option_keys
            if haskey(term.options, key)
                push!(code_lines, "    $key $(make_args(term.options[key], sep=","));")
            end
        end
        push!(code_lines, "}")
    
    elseif term.term_type == "Local"
        push!(code_lines, "Local { [ $(term.Value) ];")
        for key in option_keys
            if haskey(term.options, key)
                push!(code_lines, "    $key $(make_args(term.options[key], sep=","));")
            end
        end
        push!(code_lines, "}")

    else
        Base.error("Unsupported term type: $(term.term_type)")
    end
    join(code_lines, "\n")
end

"""
    PostQuantity

A post-processing quantity with one or more terms.
(This represents the item inside a Quantity or PostQuantity block).
"""
mutable struct PostQuantity
    name::String
    terms::Vector{QuantityTerm}
    comment::Union{String, Nothing}

    function PostQuantity(name; comment = nothing)
        new(name, QuantityTerm[], comment)
    end
end

function add!(quantity::PostQuantity, term_type, Value; comment = nothing, kwargs...)
    term =
        QuantityTerm(; term_type = term_type, Value = Value, comment = comment, kwargs...)
    push!(quantity.terms, term)
    term
end

function code(quantity::PostQuantity)
    code_lines = String[]
    if quantity.comment !== nothing
        push!(code_lines, comment(quantity.comment, newline = false))
    end
    push!(code_lines, "{ Name $(quantity.name); Value {")
    for term in quantity.terms
        term_code = code(term)
        for line in split(term_code, '\n')
            push!(code_lines, "    $line")
        end
    end
    push!(code_lines, "}}")
    join(code_lines, "\n")
end

"""
    PostproItem

An item in a post-processing section.
"""
mutable struct PostproItem
    name::String
    NameOfFormulation::String
    quantities::Vector{PostQuantity}
    post_quantities::Vector{PostQuantity} # MODIFIED: Added new list
    comment::Union{String, Nothing}
    kwargs::Dict

    # MODIFIED: Initialize both lists
    function PostproItem(name; NameOfFormulation, comment = nothing, kwargs...)
        new(name, NameOfFormulation, PostQuantity[], PostQuantity[], comment, Dict(kwargs))
    end
end

"""
    add!(item::PostproItem, name::String; comment = nothing)

Add a Quantity item (which will be wrapped in a Quantity block).
This is the default.
"""
# function add!(item::PostproItem, name::String; comment = nothing)
#     quantity = PostQuantity(name; comment = comment)
#     push!(item.quantities, quantity)
#     quantity
# end

"""
    add_quantity_term!(item::PostproItem, name::String; comment = nothing)

Explicitly add a Quantity item (which will be wrapped in a Quantity block).
"""
function add_quantity_term!(item::PostproItem, name::String; comment = nothing)
    quantity = PostQuantity(name; comment = comment)
    push!(item.quantities, quantity)
    quantity
end

"""
    add_post_quantity!(item::PostproItem, name::String; comment = nothing)

Add a PostQuantity item (which will be wrapped in a PostQuantity block).
"""
function add_post_quantity_term!(item::PostproItem, name::String; comment = nothing)
    quantity = PostQuantity(name; comment = comment)
    push!(item.post_quantities, quantity)
    quantity
end


function code(item::PostproItem)
    code_lines = ["{ Name $(item.name); NameOfFormulation $(item.NameOfFormulation);"]
    if item.comment !== nothing
        push!(code_lines, "  $(comment(item.comment, newline=false))")
    end
    
    # --- Generate Quantity block (if it has items) ---
    if !isempty(item.quantities)
        push!(code_lines, "    Quantity {")
        for quantity in item.quantities
            quantity_code = code(quantity)
            for line in split(quantity_code, '\n')
                push!(code_lines, "    $line")
            end
        end
        push!(code_lines, "    }")
    end

    # --- Generate PostQuantity block (if it has items) ---
    if !isempty(item.post_quantities)
        push!(code_lines, "    PostQuantity {")
        for quantity in item.post_quantities
            quantity_code = code(quantity)
            for line in split(quantity_code, '\n')
                push!(code_lines, "    $line")
            end
        end
        push!(code_lines, "    }")
    end
    
    push!(code_lines, "}")
    join(code_lines, "\n")
end

"""
    PostProcessing

Defining post-processing.
"""
mutable struct PostProcessing <: AbstractGetDPObject
    name::String
    content::String
    items::Vector{PostproItem}
    comment::Union{String, Nothing}
    indent::String

    function PostProcessing()
        new("PostProcessing", "", PostproItem[], nothing, " "^4)
    end
end

"""
    add!(postprocessing::PostProcessing, name::String, NameOfFormType::String; kwargs...)

Add a post-processing item.
"""
function add!(
    postprocessing::PostProcessing,
    name::String,
    NameOfFormulation::String;
    comment = nothing,
    kwargs...,
)
    item = PostproItem(
        name;
        NameOfFormulation = NameOfFormulation,
        comment = comment,
        kwargs...,
    )
    push!(postprocessing.items, item)
    postprocessing.content = code(postprocessing)
    item
end

"""
    code(postprocessing::PostProcessing)

Generate GetDP code for a PostProcessing object.
"""
function code(postprocessing::PostProcessing)
    code_lines = ["\nPostProcessing {"]
    for item in postprocessing.items
        item_code = code(item)
        for line in split(item_code, '\n')
            if !isempty(line)
                push!(code_lines, "  $line")
            end
        end
    end
    push!(code_lines, "}")
    if postprocessing.comment !== nothing
        return comment(postprocessing.comment) * "\n" * join(code_lines, "\n") * "\n"
    else
        return join(code_lines, "\n") * "\n"
    end
end

"""
    add_raw_code!(postprocessing::PostProcessing, raw_code, newline=true)

Add raw code to the PostProcessing object.
"""
function add_raw_code!(postprocessing::PostProcessing, raw_code, newline = true)
    postprocessing.content = add_raw_code(postprocessing.content, raw_code, newline)
end

"""
    add_comment!(postprocessing::PostProcessing, comment_text, newline=true)

Add a comment to the PostProcessing object.
"""
function add_comment!(postprocessing::PostProcessing, comment_text, newline = true)
    add_raw_code!(postprocessing, comment(comment_text; newline = false), newline)
end