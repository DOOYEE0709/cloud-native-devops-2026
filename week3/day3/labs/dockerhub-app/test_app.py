import json
import unittest
from unittest.mock import Mock

import app


class HandlerUnitTest(unittest.TestCase):
    def test_health_payload_shape(self):
        handler = object.__new__(app.Handler)
        handler.send_response = Mock()
        handler.send_header = Mock()
        handler.end_headers = Mock()
        handler.wfile = Mock()

        handler.write_json(200, {
            "service": "w3d3-dockerhub-app",
            "version": "0.1.0",
            "status": "ok",
        })

        handler.send_response.assert_called_once_with(200)
        body = handler.wfile.write.call_args.args[0]
        payload = json.loads(body.decode("utf-8"))
        self.assertEqual(payload["status"], "ok")
        self.assertEqual(payload["version"], "0.1.0")


if __name__ == "__main__":
    unittest.main()
