# Lazy Kurtosis

# Note: by default port jsonrpc 7980
# https://github.com/rollkit/local-da/blob/main/main.star#L4C28-L4C32
da_node = import_module("github.com/rollkit/local-da/main.star@v0.3.0")

def run(plan):
    lazy_port_number = 26657
    
    ##########
    # DA
    ##########

    da_address = da_node.run(
        plan,
    )
    plan.print("connecting to da layer via {0}".format(da_address))

    #####
    # LAZY
    #####

    plan.print("Adding LAZY service")
    plan.print("NOTE: This can take a few minutes to start up...")
    lazy_start_cmd = [
        "rollkit",
        "start",
        "--rollkit.aggregator",
        "--rollkit.da_address {0}".format(da_address),
    ]

    lazy_port_spec = PortSpec(
        number=lazy_port_number, transport_protocol="TCP", application_protocol="http"
    )
    lazy_ports = {
        "jsonrpc": lazy_port_spec,
    }
    lazy = plan.add_service(
        name="lazy",
        config=ServiceConfig(
            # Using rollkit version v0.13.5
            image="artela-rollkit-lazy",
            cmd=["/bin/sh", "-c", " ".join(lazy_start_cmd)],
            ports=lazy_ports,
            public_ports=lazy_ports,
        ),
    )

    # Set the local Lazy address to return
    lazy_address = "http://{0}:{1}".format(
        lazy.ip_address, lazy.ports["jsonrpc"].number
    )

    # lets get the myKey address same as    
    # ./entrypoint keyinfo --file ~/.artroll/keyring-test/mykey.info --passwd test
    exec_get_validator_adrress = ExecRecipe(
        command = ["rollkit","keys","list","--keyring-backend","test"],
    )

    result = plan.exec(
        service_name = "lazy",
        recipe = exec_get_validator_adrress,
        description = "Getting Validator Address"
    )

    plan.print(result["output"])
    plan.print(result["code"])

    return lazy_address

    #############
    # Lazy Bridge Frontend
    #############
    # plan.print("Adding Lazy Bridge Frontend service")
    # frontend_port_number = 3000
    # frontend_port_spec = PortSpec(
    #     number=frontend_port_number,
    #     transport_protocol="TCP",
    #     application_protocol="http",
    # )
    # frontend_ports = {
    #     "server": frontend_port_spec,
    # }
    # frontend = plan.add_service(
    #     name="hyperlane frontend",
    #     config=ServiceConfig(
    #         image="todo",
    #         ports=frontend_ports,
    #         public_ports=frontend_ports,
    #     ),
    # )