"""
Routes - UI routes and API endpoints
"""
from flask import render_template, request, jsonify
from domain_manager import read_domains, add_domain, remove_domain, validate_domain
from updater import update_all_domains
import logging

logger = logging.getLogger(__name__)


def register_routes(app):
    """
    Register all routes with the Flask app
    """
    
    @app.route('/')
    def index():
        """Main dashboard page"""
        return render_template('index.html')
    
    @app.route('/api/domains', methods=['GET'])
    def api_get_domains():
        """Get list of all domains"""
        try:
            domains = read_domains()
            return jsonify({"domains": domains}), 200
        except Exception as e:
            logger.error(f"Error reading domains: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/add', methods=['POST'])
    def api_add_domain():
        """Add a domain to the list"""
        try:
            data = request.get_json()
            if not data or 'domain' not in data:
                return jsonify({"error": "Missing 'domain' field"}), 400
            
            domain = data['domain'].strip()
            
            if not validate_domain(domain):
                return jsonify({"error": "Invalid domain format"}), 400
            
            added = add_domain(domain)
            if added:
                return jsonify({"success": True, "message": f"Domain '{domain}' added"}), 200
            else:
                return jsonify({"success": False, "message": f"Domain '{domain}' already exists"}), 200
        except ValueError as e:
            return jsonify({"error": str(e)}), 400
        except Exception as e:
            logger.error(f"Error adding domain: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/remove', methods=['POST'])
    def api_remove_domain():
        """Remove a domain from the list"""
        try:
            data = request.get_json()
            if not data or 'domain' not in data:
                return jsonify({"error": "Missing 'domain' field"}), 400
            
            domain = data['domain'].strip()
            
            removed = remove_domain(domain)
            if removed:
                return jsonify({"success": True, "message": f"Domain '{domain}' removed"}), 200
            else:
                return jsonify({"success": False, "message": f"Domain '{domain}' not found"}), 200
        except Exception as e:
            logger.error(f"Error removing domain: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/update', methods=['POST'])
    def api_update():
        """Trigger immediate DNS resolution and nftables update"""
        try:
            result = update_all_domains()
            if result["success"]:
                return jsonify({
                    "success": True,
                    "message": "Update completed",
                    "stats": {
                        "domains_processed": result["domains_processed"],
                        "domains_resolved": result["domains_resolved"],
                        "ipv4_count": result["ipv4_count"],
                        "ipv6_count": result["ipv6_count"],
                        "failed_domains": result["failed_domains"]
                    }
                }), 200
            else:
                return jsonify({"success": False, "error": "Update failed"}), 500
        except Exception as e:
            logger.error(f"Error updating domains: {e}")
            return jsonify({"error": str(e)}), 500

