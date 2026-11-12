module Epidemic

using Agents
using Random
using WGLMakie

import bonito

include("model_agent.jl")

# Public API
export HealthStatus, susceptible, exposed, infected, recovered
export Person, ModelParams
export initialize_model, agent_step!

end
