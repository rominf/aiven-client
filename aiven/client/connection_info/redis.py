from ._utils import find_component, find_user, format_uri
from .common import ConnectionInfoError


class RedisConnectionInfo:
    def __init__(self, host, port, username, db, password):
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.db = db

    @classmethod
    def from_service(cls, service, *, route, usage, privatelink_connection_id, username, db):
        if service["service_type"] != "redis":
            raise ConnectionInfoError(
                "Cannot format redis connection info for service type {service_type}".format_map(service)
            )

        info = find_component(
            service["components"], route=route, usage=usage, privatelink_connection_id=privatelink_connection_id
        )
        host = info["host"]
        port = info["port"]
        if username == "default":
            password = service['connection_info']['redis_password']
        else:
            user = find_user(service, username)
            password = user.get("password")

        if password is None:
            raise ConnectionInfoError(f"Could not find password for username {username}")
        return cls(host=host, port=port, username=username, db=db, password=password)

    def params(self):
        return {
            "host": self.host,
            "port": self.port,
            "user": self.username,
            "db": self.db,
            "password": self.password,
        }

    def uri(self):
        return format_uri(
            scheme="rediss",
            username=self.username,
            password=self.password,
            host=self.host,
            port=self.port,
            path=f"/{self.db}" if self.db else '',
            query={},
        )
