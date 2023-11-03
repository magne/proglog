package auth

import (
	"fmt"

	"github.com/casbin/casbin/v2"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type (
	Authorizer struct {
		enforcer *casbin.Enforcer
	}
)

func New(model, policy string) (*Authorizer, error) {
	enforcer, err := casbin.NewEnforcer(model, policy)
	if err != nil {
		return nil, err
	}
	return &Authorizer{
		enforcer: enforcer,
	}, err
}

func (a *Authorizer) Authorize(subject, object, action string) error {
	if ok, err := a.enforcer.Enforce(subject, object, action); err != nil {
		return err
	} else if !ok {
		msg := fmt.Sprintf("%s not permitted to %s on %s", subject, action, object)
		st := status.New(codes.PermissionDenied, msg)
		return st.Err()
	}
	return nil
}
