"""
Main Flask application entrypoint
"""
from flask import Flask
from waitress import serve
import logging
from config import HOST, PORT, DEBUG
from routes import register_routes

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config['JSONIFY_PRETTYPRINT_REGULAR'] = True

# Register all routes
register_routes(app)


def main():
    """Main entry point"""
    logger.info(f"Starting WG-Domain Routing Web UI on {HOST}:{PORT}")
    
    if DEBUG:
        # Development mode with Flask's built-in server
        app.run(host=HOST, port=PORT, debug=True)
    else:
        # Production mode with Waitress
        serve(app, host=HOST, port=PORT, threads=4)


if __name__ == '__main__':
    main()

