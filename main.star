# Lazy Kurtosis

# Note: by default port jsonrpc 7980
# https://github.com/rollkit/local-da/blob/main/main.star#L4C28-L4C32
da_node = import_module("github.com/rollkit/local-da/main.star@v0.3.0")

def run(
    plan,
    public_rpc_port=26657
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

    plan.print("LAZY service")

    service_name="lazy-local"
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

    lazy = plan.add_service(name=service_name,config=service_config)

    # Create development account
    create_dev_wallet = plan.exec(
        description="Creating Development Account",
        service_name=service_name,
        recipe=ExecRecipe(
            command=[
                "/bin/sh",
                "-c",
                "artrolld keys add dev01 --keyring-backend test --output json | jq '.address |add'",
            ]
        ),
    )["output"]

    cmd = "artrolld keys list --keyring-backend test --output json | jq -r '[.[] | {(.name): .address}] | tostring | fromjson | reduce .[] as $item ({} ; . + $item)' | jq '.validator' | sed 's/\"//g;' | tr '\n' ' ' | tr -d ' '"
    validator_addr = plan.exec(
        description="Getting Validator Address",
        service_name=service_name,
        recipe=ExecRecipe(
            command=[
                "/bin/sh",
                "-c",
                cmd,
            ]
        ),
    )["output"]

    cmd = "artrolld keys list --keyring-backend test --output json | jq -r '[.[] | {(.name): .address}] | tostring | fromjson | reduce .[] as $item ({} ; . + $item)' | jq '.dev01' | sed 's/\"//g;' | tr '\n' ' ' | tr -d ' '"
    dev_addr = plan.exec(
        description="Getting Validator Address",
        service_name=service_name,
        recipe=ExecRecipe(
            command=[
                "/bin/sh",
                "-c",
                cmd,
            ]
        ),
    )["output"]

    # kurtosis is so limited that we need to filter \n and to use that we need tr....
    cmd="artrolld tx bank send {0} {1} 1000000ulzy --keyring-backend test --fees 500ulzy -y".format(validator_addr,dev_addr)

    fund_wallet = plan.exec(
        description="Funding dev wallet {0}".format(dev_addr),
        service_name=service_name,
        recipe=ExecRecipe(
            command=[
                "/bin/sh",
                "-c",
                cmd,
            ]
        ),
    )["output"]

    return { "validator_addr" : validator_addr, "dev_addr" : dev_addr }

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
    