package server

import (
	"fmt"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	rpcclient "github.com/cometbft/cometbft/rpc/jsonrpc/client"
	dbm "github.com/cosmos/cosmos-db"
	"github.com/cosmos/cosmos-sdk/client"
	sdkserver "github.com/cosmos/cosmos-sdk/server"
	ethlog "github.com/ethereum/go-ethereum/log"

	ethrpc "github.com/artela-network/artela-rollkit/ethereum/rpc"
	"github.com/artela-network/artela-rollkit/ethereum/server/config"
)

// CreateJSONRPC starts the JSON-RPC server
func CreateJSONRPC(ctx *sdkserver.Context,
	clientCtx client.Context,
	tmRPCAddr,
	tmEndpoint string,
	config *config.Config,
) (*ethrpc.ArtelaService, error) {
	cfg := ethrpc.DefaultConfig()
	cfg.RPCGasCap = config.JSONRPC.GasCap
	cfg.RPCEVMTimeout = config.JSONRPC.EVMTimeout
	cfg.RPCTxFeeCap = config.JSONRPC.TxFeeCap
	cfg.AppCfg = config

	nodeCfg := ethrpc.DefaultGethNodeConfig()
	address := strings.Split(config.JSONRPC.Address, ":")
	if len(address) > 0 {
		nodeCfg.HTTPHost = address[0]
	}
	if len(address) > 1 {
		port, err := strconv.Atoi(address[1])
		if err != nil {
			return nil, fmt.Errorf("address of JSON RPC Configuration is not valid, %w", err)
		}
		nodeCfg.HTTPPort = port
	}

	logger := ctx.Logger.With("module", "geth")
	nodeCfg.Logger = ethlog.New()
	nodeCfg.Logger.SetHandler(ethlog.FuncHandler(func(r *ethlog.Record) error {
		switch r.Lvl {
		case ethlog.LvlTrace, ethlog.LvlDebug:
			logger.Debug(r.Msg, r.Ctx...)
		case ethlog.LvlInfo, ethlog.LvlWarn:
			logger.Info(r.Msg, r.Ctx...)
		case ethlog.LvlError, ethlog.LvlCrit:
			logger.Error(r.Msg, r.Ctx...)
		}
		return nil
	}))
	// do not start websocket
	nodeCfg.WSHost = ""
	stack, err := ethrpc.NewNode(nodeCfg)
	if err != nil {
		return nil, err
	}

	wsClient := ConnectTmWS(tmRPCAddr, tmEndpoint, nodeCfg.Logger)

	serv := ethrpc.NewArtelaService(ctx, clientCtx, wsClient, cfg, stack, nodeCfg.Logger)

	// allocate separate WS connection to Tendermint
	tmWsClient := ConnectTmWS(tmRPCAddr, tmEndpoint, nodeCfg.Logger)
	wsSrv := ethrpc.NewWebsocketsServer(clientCtx, tmWsClient, config, nodeCfg.Logger)
	wsSrv.Start()

	return serv, nil
}

func openDB(rootDir string, backendType dbm.BackendType) (dbm.DB, error) {
	dataDir := filepath.Join(rootDir, "data")
	return dbm.NewDB("application", backendType, dataDir)
}

func ConnectTmWS(tmRPCAddr, tmEndpoint string, logger ethlog.Logger) *rpcclient.WSClient {
	tmWsClient, err := rpcclient.NewWS(tmRPCAddr, tmEndpoint,
		rpcclient.MaxReconnectAttempts(256),
		rpcclient.ReadWait(120*time.Second),
		rpcclient.WriteWait(120*time.Second),
		rpcclient.PingPeriod(50*time.Second),
		rpcclient.OnReconnect(func() {
			logger.Debug("EVM RPC reconnects to Tendermint WS", "address", tmRPCAddr+tmEndpoint)
		}),
	)

	if err != nil {
		logger.Error(
			"Tendermint WS client could not be created",
			"address", tmRPCAddr+tmEndpoint,
			"error", err,
		)
	} else if err := tmWsClient.OnStart(); err != nil {
		logger.Error(
			"Tendermint WS client could not start",
			"address", tmRPCAddr+tmEndpoint,
			"error", err,
		)
	}

	return tmWsClient
}
