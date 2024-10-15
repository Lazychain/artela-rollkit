# Lazy Kurtosis

# Note: by default port jsonrpc 7980
# https://github.com/rollkit/local-da/blob/main/main.star#L4C28-L4C32
da_node = import_module("github.com/rollkit/local-da/main.star@v0.3.0")

def run(
    plan,
    dummy_mnemonic="", # this must be provided
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
    # lazy_start_cmd = [
    #     "rollkit",
    #     "start",
    #     "--rollkit.aggregator",
    #     "--rollkit.da_address {0}".format(da_address),
    # ]

    service_config=ServiceConfig(
        # Using rollkit version v0.13.5
        image="ghcr.io/lazychain/artela-rollkit-lazy:v0.0.1-beta2",
        # cmd=["/bin/sh", "-c", " ".join(lazy_start_cmd)],
        ports={ "rpc": PortSpec(number=26657,transport_protocol="TCP",application_protocol="http")},
        # create public port so that is exposed on machine and available for peering
        public_ports={ "rpc": PortSpec(number=public_rpc_port, transport_protocol="TCP",application_protocol="http")},
        env_vars = { "DA_ADDRESS": da_address },
    )

    lazy = plan.add_service(name=service_name,config=service_config)

    # Create development account
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

    # this command succeed but produces the following error

    #     --------------------
    # panic: runtime error: invalid memory address or nil pointer dereference
    # [signal SIGSEGV: segmentation violation code=0x1 addr=0x0 pc=0x10f6b9c]

    # goroutine 1 [running]:
    # github.com/cosmos/cosmos-sdk/codec.(*LegacyAmino).jsonMarshalAnys(0x49a8880?, {0x49a8880?, 0xc001622460?})
    # 	/go/pkg/mod/github.com/cosmos/cosmos-sdk@v0.50.6/codec/amino.go:72 +0x1c
    # github.com/cosmos/cosmos-sdk/codec.(*LegacyAmino).MarshalJSON(0x0, {0x49a8880, 0xc001622460})
    # 	/go/pkg/mod/github.com/cosmos/cosmos-sdk@v0.50.6/codec/amino.go:143 +0x25
    # github.com/artela-network/artela-rollkit/client/keys.printCreate(0xc0012b4908, 0x8b6c4c0?, 0x1, {0xc000e4ef00, 0x95}, {0x7fff6d94df52?, 0x1?})
    # 	/app/client/keys/add.go:283 +0x2a5
    # github.com/artela-network/artela-rollkit/client/keys.RunAddCmd({{0x0, 0x0, 0x0}, {0x60e4818, 0xc0017c09f0}, 0x0, {0xc0007dd680, 0xf}, {0x610a790, 0xc0014c6a80}, ...}, ...)
    # 	/app/client/keys/add.go:254 +0xc45
    # github.com/artela-network/artela-rollkit/client.runAddCmd(0xc0012b4908, {0xc00150bc20, 0x1, 0x5})
    # 	/app/client/keys.go:92 +0x345
    # github.com/spf13/cobra.(*Command).execute(0xc0012b4908, {0xc00150bbd0, 0x5, 0x5})
    # 	/go/pkg/mod/github.com/spf13/cobra@v1.8.1/command.go:985 +0xaca
    # github.com/spf13/cobra.(*Command).ExecuteC(0xc001779808)
    # 	/go/pkg/mod/github.com/spf13/cobra@v1.8.1/command.go:1117 +0x3ff
    # github.com/spf13/cobra.(*Command).Execute(...)
    # 	/go/pkg/mod/github.com/spf13/cobra@v1.8.1/command.go:1041
    # github.com/spf13/cobra.(*Command).ExecuteContext(...)
    # 	/go/pkg/mod/github.com/spf13/cobra@v1.8.1/command.go:1034
    # github.com/cosmos/cosmos-sdk/server/cmd.Execute(0xc001779808, {0x0, 0x0}, {0xc00139d3c0, 0xe})
    # 	/go/pkg/mod/github.com/cosmos/cosmos-sdk@v0.50.6/server/cmd/execute.go:34 +0x187
    # main.main()
    # 	/app/cmd/artrolld/main.go:15 +0x33

    # --------------------

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
    cmd="artrolld tx bank send {0} {1} 1000000uart --keyring-backend test --fees 500uart -y".format(validator_addr,dev_addr)
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
    