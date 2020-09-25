include("../src/NursesScheduling.jl")
include("parameters.jl")
using .NurseSchedules
using .NurseSchedules: Shifts
using Logging
using StatsBase: sample

import Base.in

logger = ConsoleLogger(stderr, Logging.Debug)

BestResult = @NamedTuple{shifts::Shifts, score::Number}

using BenchmarkTools

function in(shifts::Shifts, tabu_list::Vector{BestResult})
    findfirst(record -> record.shifts == shifts, tabu_list) != nothing
end

function eval_frozen_shifts(
    month_info,
    errors::Vector,
    no_improved_iters::Int,
    workers,
)::Vector{Tuple{Int,Int}}
    frozen_days = [(0, day_no) for day_no in month_info["frozen_days"]]
    num_days = length(month_info["children_number"])
    num_wrks = length(workers)

    exclusion_range = if no_improved_iters > 16
        return frozen_days
    elseif no_improved_iters > 8
        1
    else
        0
    end

    day_errors = filter(error -> haskey(error, "day"), errors)
    frozen_shifts = if !isempty(day_errors)
        changeable_days = Vector{Int}()
        for error in day_errors
            for i = 0:exclusion_range
                push!(changeable_days, error["day"] + i)
                i > 0 && push!(changeable_days, error["day"] - i)
            end
        end

        println("Days being improved: $(length(changeable_days))")
        [(0, day_no) for day_no in setdiff(Set(1:num_days), Set(changeable_days))]
    else
        worker_errors = filter(error -> !haskey(error, "day"), errors)

        changeable_wrks = [
            findfirst(wrk_id -> wrk_id == error["worker"], workers)
            for error in worker_errors
        ]
        no_improved_iters == 1 && push!(
            changeable_wrks,
            sample(collect(
                1:num_wrks,
                floor(Int, num_wrks * WRKS_RANDOM_FACTOR),
                replace = false,
            )),
        )
        println("Workers being improved: $(length(changeable_wrks))")
        [(wrk_no, 0) for wrk_no in setdiff(Set(1:num_wrks), Set(changeable_wrks))]
    end

    vcat(frozen_days, frozen_shifts)
end

nurse_schedule = Schedule(SCHEDULE_PATH)

schedule_shifts = get_shifts(nurse_schedule)
workers, shifts = schedule_shifts
month_info = get_month_info(nurse_schedule)
workers_info = get_workers_info(nurse_schedule)

penalty = score(schedule_shifts, month_info, workers_info)
best_res = BestResult((shifts = shifts, score = penalty))
best_iter_res = BestResult((shifts = best_res.shifts, score = Inf))

tabu_list = Vector{BestResult}()
push!(tabu_list, best_res)
max_tabu_size = INITIAL_MAX_TABU_SIZE
no_improved_iters = 0

for i = 1:ITERATION_NUMBER
    global best_iter_res = BestResult((shifts = best_iter_res.shifts, score = Inf))

    _, errors = score((workers, best_iter_res.shifts), month_info, workers_info, true)
    act_frozen_days = eval_frozen_shifts(month_info, errors, no_improved_iters, workers)
    nbhd = Neighborhood(best_iter_res.shifts, act_frozen_days)
    for candidate_shifts in nbhd
        candidate_score = score((workers, candidate_shifts), month_info, workers_info)
        if best_iter_res.score > candidate_score && !(candidate_shifts in tabu_list)
            global best_iter_res = BestResult((candidate_shifts, candidate_score))
        end
    end

    println("[Iteration '$(i)']")
    if best_res.score > best_iter_res.score
        println("Penalty: '$(best_res.score)' -> '$(best_iter_res.score)' ($(best_iter_res.score - best_res.score))")
        global best_res = best_iter_res
        global no_improved_iters = 0
    else
        global no_improved_iters += 1
    end

    push!(tabu_list, best_iter_res)

    while length(tabu_list) > max_tabu_size
        popfirst!(tabu_list)
    end

    if no_improved_iters < INC_TABU_SIZE_ITER
        global max_tabu_size = INITIAL_MAX_TABU_SIZE
        length(tabu_list) > INITIAL_MAX_TABU_SIZE &&
            println("Reseting max tabu size to: $(max_tabu_size)")
    elseif length(tabu_list) == max_tabu_size
        global max_tabu_size += 1
        println("Incrementing max tabu size to: $(max_tabu_size)")
    end

    if best_res.score == 0
        println("We will not be better, finishing.")
        break
    end
    println("Iteration best score: $(best_iter_res.score)")
end

with_logger(logger) do
    improved_penalty, errors =
        score((workers, best_res.shifts), month_info, workers_info, true)
    println("Penaly improved: '$(penalty)' -> '$(improved_penalty)'")
end