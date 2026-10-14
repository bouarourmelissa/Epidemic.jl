# ----------------------------------------------------
# 1. Agent Definition (SEIRS: Susceptible → Exposed → Infected → Recovered → Susceptible)
# ----------------------------------------------------
@enum HealthStatus susceptible exposed infected recovered

@agent struct Person(GridAgent{2})
    status::HealthStatus = susceptible
    infection_timer::Int = 0
    exposure_timer::Int  = 0
    immunity_timer::Int  = 0
    age::Int             = 0
    wearing_mask::Bool   = false
    vaccinated::Bool     = false
end

# ----------------------------------------------------
# 2. Model Parameters
# ----------------------------------------------------
struct ModelParams
    infectiousness::Float64          # Probability of infection on contact
    latency_period::Int              # Duration of exposed (latent) phase in ticks
    duration::Int                    # Duration of infected phase in ticks
    chance_recover::Float64          # Probability of recovery vs death
    immunity_duration::Int           # Ticks of immunity after recovery
    birth_rate::Float64              # Probability of reproduction per tick
    carrying_capacity::Int           # Maximum population cap
    max_age::Int                     # Maximum lifetime in ticks
    mask_effectiveness::Float64      # Reduction factor when wearing a mask
    mask_probability::Float64        # Probability that an agent wears a mask
    vaccine_effectiveness::Float64   # Reduction factor when vaccinated
    vaccination_probability::Float64 # Probability that an agent is vaccinated
end

# ----------------------------------------------------
# 3. Agent Dynamics (Step Function)
# ----------------------------------------------------
function agent_step!(agent::Person, model)
    params = abmproperties(model)

    # A. Aging and Natural Death
    agent.age += 1
    if agent.age >= params.max_age
        remove_agent!(agent, model)
        return
    end

    # B. Movement (random walk to neighboring cells, including diagonals)
    randomwalk!(agent, model)

    # C. Disease Progression (SEIRS)
    if agent.status == exposed
        # E to I : after the latency period, the agent becomes infectious
        agent.exposure_timer += 1
        if agent.exposure_timer >= params.latency_period
            agent.status = infected
            agent.exposure_timer = 0
            agent.infection_timer = 0
        end

    elseif agent.status == infected
        # I to R (or death) : after the infection duration
        agent.infection_timer += 1
        if agent.infection_timer >= params.duration
            if rand(abmrng(model)) < params.chance_recover
                agent.status = recovered
                agent.infection_timer = 0
                agent.immunity_timer = 0
            else
                remove_agent!(agent, model)
                return
            end
        end

    elseif agent.status == recovered
        # R to S : immunity wanes, completing the SEIRS cycle
        agent.immunity_timer += 1
        if agent.immunity_timer >= params.immunity_duration
            agent.status = susceptible
            agent.immunity_timer = 0
        end
    end

    # D. Transmission: infected agents expose susceptible co-located neighbors
    if agent.status == infected
        for neighbor in agents_in_position(agent, model)
            neighbor.id == agent.id && continue  # skip self

            if neighbor.status == susceptible
                transmission_prob = params.infectiousness

                # Mask on the infected agent reduces outward transmission
                if agent.wearing_mask
                    transmission_prob *= (1 - params.mask_effectiveness)
                end

                # Mask on the susceptible agent reduces inward transmission
                if neighbor.wearing_mask
                    transmission_prob *= (1 - params.mask_effectiveness)
                end

                # Vaccine protects the susceptible agent
                if neighbor.vaccinated
                    transmission_prob *= (1 - params.vaccine_effectiveness)
                end

                if rand(abmrng(model)) < transmission_prob
                    neighbor.status = exposed        # S to E (not directly to I)
                    neighbor.exposure_timer = 0
                end
            end
        end
    end

   # E. Reproduction (demographic birth)
    if nagents(model) < params.carrying_capacity
        if rand(abmrng(model)) < params.birth_rate
            wears_mask = rand(abmrng(model)) < params.mask_probability
            is_vaccinated = rand(abmrng(model)) < params.vaccination_probability
            add_agent!(agent.pos, model;
                       status = susceptible,
                       age = 0,
                       wearing_mask = wears_mask,
                       vaccinated = is_vaccinated)
        end
    end
end

# ----------------------------------------------------
# 4. Model Initialization
# ----------------------------------------------------
function initialize_model(;
    dims = (35, 35),
    n_agents = 150,
    initial_infected = 10,
    infectiousness = 0.65,
    latency_period = 8,
    duration = 25,
    chance_recover = 0.60,
    immunity_duration = 40,
    birth_rate = 0.015,
    carrying_capacity = 300,
    max_age = 500,
    seed = 42,
    mask_probability = 0.5,
    mask_effectiveness = 0.5,
    vaccine_effectiveness = 0.7,
    vaccination_probability = 0.6,
)
    space = GridSpace(dims; periodic = true)

    properties = ModelParams(
        infectiousness,
        latency_period,
        duration,
        chance_recover,
        immunity_duration,
        birth_rate,
        carrying_capacity,
        max_age,
        mask_effectiveness,
        mask_probability,
        vaccine_effectiveness,
        vaccination_probability,
    )

    rng = Xoshiro(seed)
    model = StandardABM(Person, space; agent_step!, properties, rng)

    # Populate agents
    for i in 1:n_agents
        status = (i <= initial_infected) ? infected : susceptible
        rand_age = rand(rng, 1:max_age)
        wears_mask = rand(rng) < mask_probability
        is_vaccinated = rand(rng) < vaccination_probability
        add_agent!(model;
                   status, age = rand_age,
                   wearing_mask = wears_mask, vaccinated = is_vaccinated)
    end

    return model
end
