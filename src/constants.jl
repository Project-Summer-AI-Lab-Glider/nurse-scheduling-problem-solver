# CUSTOM TYPES
#
# Scoring
ScoringResult = @NamedTuple{penalty::Int, errors::Vector{Dict{String,Any}}}
ScoringResultOrPenalty = Union{ScoringResult,Int}
# Schedule related
Workers = Vector{String}
Shifts = Array{String,2}
ScheduleShifts = Tuple{Workers,Shifts}
# Neighborhood
@se Mutation begin
    ADD => "ADDITION"
    DEL => "DELETION"
    SWP => "SWAP"
end
IntOrTuple = Union{Int,Tuple{Int,Int}}
StringOrNothing = Union{String,Nothing}
MutationRecipe = @NamedTuple{
    type::Mutation.MutationEnum,
    day::Int,
    wrk_no::IntOrTuple,
    optional_info::StringOrNothing,
}

# shift types
const R = "R"    # morning (7-15)
const P = "P"    # afternoon (15-19)
const D = "D"    # daytime == R + P (7-19)
const N = "N"    # night (19-7)
const DN = "DN"  # day == D + N (7-7)
const PN = "PN"  # afternoon-night == P + N (15-7)
const W = "W"    # day free
const U = "U"    # vacation
const L4 = "L4"  # sick leave

# decrease required worktime
const SHIFTS_EXEMPT = [U, L4]

const REQ_CHLDN_PER_NRS_DAY = 3
const REQ_CHLDN_PER_NRS_NIGHT = 5

# there has to be such a seq each week
const LONG_BREAK_SEQ = (([U, L4, W], [N, U, L4, W]), ([R, P, D], [U, L4, W]))

# under and overtime pen is equal to hours from <0, MAX_OVERTIME>
const MAX_OVERTIME = 10 # scaled by the number of weeks
const MAX_UNDERTIME = 0 # scaled by the number of weeks

const CONFIG = JSON.parsefile("config/default/priorities.json")
const SHIFTS = JSON.parsefile("config/default/shifts.json")
const DAY_BEGIN = 7
const NIGHT_BEGIN = 19

# weekly worktime
const WORKTIME_BASE = 40

const DAY_HOURS_NO = 24
const WEEK_DAYS_NO = 7
const NUM_WORKING_DAYS = 5
const SUNDAY_NO = 0

const WORKTIME_DAILY = WORKTIME_BASE / NUM_WORKING_DAYS

@se Constraints begin
    PEN_LACKING_NURSE => "AON"
    PEN_LACKING_WORKER => "WND"
    PEN_LACKING_WORKER_NIGHT => "WNN"
    PEN_NO_LONG_BREAK => "LLB"
    PEN_DISALLOWED_SHIFT_SEQ => "DSS"
end

@se WorkerType begin
    NURSE => "NURSE"
    OTHER => "OTHER"
end

@se ErrorCode begin
    ALWAYS_AT_LEAST_ONE_NURSE => "AON"
    WORKERS_NO_DURING_DAY => "WND"
    WORKERS_NO_DURING_NIGHT => "WNN"
    DISALLOWED_SHIFT_SEQ => "DSS"
    LACKING_LONG_BREAK => "LLB"
    WORKER_UNDERTIME_HOURS => "WUH"
    WORKER_OVERTIME_HOURS => "WOH"
end
