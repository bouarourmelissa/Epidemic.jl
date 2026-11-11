

using Epidemic, Agents, WGLMakie
import Bonito

WGLMakie.activate!()
set_theme!(theme_dark())

include("visualisation.jl")   # modèle agent + graphiques + simulation
include("interface_web.jl")   # page web

app = creer_app()

server = Bonito.Server(app, "127.0.0.1", 8080)
println("Ouvrez http://127.0.0.1:8080 dans votre navigateur")
wait(server)