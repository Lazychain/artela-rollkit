# Lazy Kurtosis

# Note: by default port jsonrpc 7980
# https://github.com/rollkit/local-da/blob/main/main.star#L4C28-L4C32
da_node = import_module("github.com/rollkit/local-da/main.star@v0.3.0")

def run(
    plan,
    dummy_mnemonic="", # this must be provided
    public_rpc_port=26657,
    public_p2p_port=26656,
    public_proxy_port=26658,
    public_grpc_port=9090,
    public_grpc_web_port=9091,
    public_json_rpc_port=8545,
    public_rest_port=1317
):

    ##########
    # DA
    ##########

    da_address = da_node.run(plan)
    plan.print("connecting to da layer via {0}".format(da_address))

    #####
    # LAZY
    #####

    plan.print("LAZY service")
    service_name="lazy-local"

    service_config=ServiceConfig(
        # Using rollkit version v0.13.5
        image="ghcr.io/lazychain/artela-rollkit-lazy:v0.0.1-beta5",
        ports={ 
            "rpc": PortSpec(number=26657,transport_protocol="TCP",application_protocol="http"),
            "rest": PortSpec(number=1317,transport_protocol="TCP",application_protocol="http"),
            "json-rpc": PortSpec(number=8545,transport_protocol="TCP",application_protocol="http")

            },
        public_ports={ 
            "rpc": PortSpec(number=public_rpc_port, transport_protocol="TCP",application_protocol="http"),
            "rest": PortSpec(number=public_rest_port,transport_protocol="TCP",application_protocol="http"),
            "json-rpc": PortSpec(number=public_json_rpc_port,transport_protocol="TCP",application_protocol="http")            
            },
        env_vars = { "DA_ADDRESS": da_address },
    )

    lazy = plan.add_service(name=service_name,config=service_config)

    # 1. Create development account
    cmd = "echo \"{0}\" | artrolld keys add dev01 --keyring-backend test --output json --recover | jq '.address |add'".format(dummy_mnemonic)
    create_dev_wallet = plan.exec(
        description="Creating Development Account",
        service_name=service_name,
        recipe=ExecRecipe(
            command=[
                "/bin/sh",
                "-c",
                cmd,
            ]
        ),
    )["output"]

    # 2. Get validator wallet address
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

    # 3. Get developer wallet address
    cmd = "artrolld keys list --keyring-backend test --output json | jq -r '[.[] | {(.name): .address}] | tostring | fromjson | reduce .[] as $item ({} ; . + $item)' | jq '.dev01' | sed 's/\"//g;' | tr '\n' ' ' | tr -d ' '"
    dev_addr = plan.exec(
        description="Getting Dev Address",
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
    # 4. Fund developer wallet with validator wallet
    cmd="artrolld tx bank send {0} {1} 100000000000000000000aart --keyring-backend test --fees 4000000000000000aart -y --output json 2> /dev/null | jq '.txhash' | sed 's/\"//g;' | tr '\n' ' ' | tr -d ' '".format(validator_addr,dev_addr)
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

    # 5. check developer wallet balances next epoch
    cmd="sleep 6 && artrolld query bank balances {0}".format(dev_addr)
    fund_wallet = plan.exec(
        description="Checking dev wallet balance {0}".format(dev_addr),
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
    
