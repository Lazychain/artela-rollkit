# Lazy Kurtosis

# Note: by default port jsonrpc 7980
# https://github.com/rollkit/local-da/blob/main/main.star#L4C28-L4C32
da_node = import_module("github.com/rollkit/local-da/main.star@v0.3.0")

def run(
    plan,
    public_rpc_port
):

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

    service_config=ServiceConfig(
        # Using rollkit version v0.13.5
        image="ghcr.io/lazychain/artela-rollkit-lazy:v0.0.1-beta1",
        cmd=["/bin/sh", "-c", " ".join(lazy_start_cmd)],
        ports={ "rpc": PortSpec(number=26657,transport_protocol="TCP",application_protocol="http")},
        # create public port so that is exposed on machine and available for peering
        public_ports={ "rpc": PortSpec(number=public_rpc_port, transport_protocol="TCP",application_protocol="http")}
    )

    lazy = plan.add_service(name="lazy",config=service_config)

    # Set the local Lazy address to return
    lazy_address = "http://{0}:{1}".format(
        lazy.ip_address, lazy.ports["rpc"].number
    )

    plan.print(lazy_address)

    # lets get the myKey address same as    
    # ./entrypoint keyinfo --file ~/.artroll/keyring-test/mykey.info --passwd test
    exec_get_validator_adrress = ExecRecipe(
        command = ["rollkit","keys","list","--keyring-backend","test","--output","json"],
        extract = { "address" : "fromjson | .[0].address" },
    )

    result = plan.exec(
        service_name = "lazy",
        recipe = exec_get_validator_adrress,
        description = "Getting Validator Address"
    )

    plan.print(result["extract.address"])

    return { "validator_addr" : result["extract.address"] }

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
    