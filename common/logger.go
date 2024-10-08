package common

import (
	"cosmossdk.io/log"
	"github.com/artela-network/aspect-runtime/types"
)

var _ types.Logger = (*runtimeLoggerWrapper)(nil)

type runtimeLoggerWrapper struct {
	log.Logger
}

func WrapLogger(logger log.Logger) types.Logger {
	return &runtimeLoggerWrapper{logger}
}

func (r runtimeLoggerWrapper) With(keyvals ...interface{}) types.Logger {
	return &runtimeLoggerWrapper{r.Logger.With(keyvals...)}
}
