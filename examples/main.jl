using Epidemic





creer_app()

server = Bonito.Server(app, "127.0.0.1", 8080)
println("Ouvrez http://127.0.0.1:8080 dans votre navigateur")
wait(server)
