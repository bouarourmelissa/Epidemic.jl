using Agents
using Random
using CairoMakie
using DataFrames

# ----------------------------------------------------
# 1. Agent Definition
# ----------------------------------------------------
@enum HealthStatus susceptible infected immune

@agent struct Person(GridAgent{2})
    status::HealthStatus = susceptible
    infection_timer::Int = 0
    immunity_timer::Int  = 0
    age::Int             = 0
end

# ----------------------------------------------------
# 2. Model Initialization
# ----------------------------------------------------
struct ModelParams
    infectiousness::Float64   # Probability of infection on contact (e.g., 0.65)
    duration::Int             # Duration of infection in ticks (e.g., 20)
    chance_recover::Float64   # Probability of recovery vs death (e.g., 0.50)
    immunity_duration::Int    # Ticks immune after recovery (e.g., 50)
    birth_rate::Float64       # Probability of reproduction per tick (e.g., 0.01)
    carrying_capacity::Int    # Max population cap (e.g., 300)
    max_age::Int              # Max lifetime in ticks (e.g., 200)
end

function initialize_model(;
    dims = (35, 35),
    n_agents = 150,
    initial_infected = 10,
    infectiousness = 0.65,
    duration = 25,
    chance_recover = 0.60,
    immunity_duration = 40,
    birth_rate = 0.015,
    carrying_capacity = 300,
    max_age = 110,
    seed = 42
)
    # NetLogo uses a periodic toroidal grid where multiple agents can share a patch
    space = GridSpace(dims; periodic = true)
    
    properties = ModelParams(
        infectiousness,
        duration,
        chance_recover,
        immunity_duration,
        birth_rate,
        carrying_capacity,
        max_age
    )
    
    rng = Xoshiro(seed)
    model = StandardABM(Person, space; agent_step!, properties, rng)

    # Populate agents randomly
    for i in 1:n_agents
        status = (i <= initial_infected) ? infected : susceptible
        rand_age = rand(rng, 1:max_age)
        add_agent_single!(model; status = status, age = rand_age)
    end

    return model
end

# ----------------------------------------------------
# 3. Agent Dynamics (Step Function)
# ----------------------------------------------------
function agent_step!(agent::Person, model)
    params = model.properties

    # A. Aging and Natural Death
    agent.age += 1
    if agent.age >= params.max_age
        remove_agent!(agent, model)
        return
    end

    # B. Movement (Random walk to neighboring cells, including diagonals)
    walk!(agent, rand, model)

    # C. Virus Progression & Recovery
    if agent.status == infected
        agent.infection_timer += 1
        if agent.infection_timer >= params.duration
            if rand(abmrng(model)) < params.chance_recover
                agent.status = immune
                agent.infection_timer = 0
                agent.immunity_timer = 0
            else
                remove_agent!(agent, model)
                return
            end
        end
    elseif agent.status == immune
        agent.immunity_timer += 1
        if agent.immunity_timer >= params.immunity_duration
            agent.status = susceptible
            agent.immunity_timer = 0
        end
    end

    # D. Transmission: An infected agent infects susceptible co-located neighbors
    if agent.status == infected
        # Find all agents occupying the same patch / grid cell
        for neighbor in agents_in_position(agent, model)
            if neighbor.status == susceptible && rand(abmrng(model)) < params.infectiousness
                neighbor.status = infected
                neighbor.infection_timer = 0
            end
        end
    end

    # E. Reproduction (Demographic Birth)
    if nagents(model) < params.carrying_capacity
        if rand(abmrng(model)) < params.birth_rate
            # Newborn placed at the parent's position
            add_agent!(agent.pos, model; status = susceptible, age = 0)
        end
    end
end
