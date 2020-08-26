
export get_month_info, get_shifts, get_workers_info, update_shifts!


mutable struct Schedule
    data::Dict

    function Schedule(filename::AbstractString)
        data = JSON.parsefile(filename)
        @info "Schedule loaded!"

        validate(data)

        new(data)
    end

end

function get_shifts(schedule::Schedule)::Tuple{Array{String,1},Array{String,2}}
    shifts = collect(values(schedule.data["shifts"]))
    workers = collect(keys(schedule.data["shifts"]))
    return workers,
    [shifts[person][shift] for person = 1:length(shifts), shift = 1:length(shifts[1])]
end

function get_month_info(schedule::Schedule)::Dict{String,Any}
    return schedule.data["month_info"]
end

function get_workers_info(schedule::Schedule)::Dict{String,Any}
    return schedule.data["employee_info"]
end

function update_shifts!(workers, shifts, schedule::Schedule)
    for worker_no in axes(shifts, 1)
        schedule.data["shifts"][workers[worker_no]] = shifts[worker_no]
    end
end
