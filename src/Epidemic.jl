module Epidemic

using Agents
using Random
using WGLMakie

include("interface/visualisation.jl")
include("interface/interface_web.jl")

include("model_agent.jl")

# Public API
export HealthStatus, susceptible, exposed, infected, recovered
export Person, ModelParams
export TransmissionStrategy, BasicTransmission, ProtectedTransmission
export initialize_model, agent_step!
export creer_app
end
