CREATE OR REPLACE PACKAGE BODY dom IS

    /*
        Copyright 2019 Sergejs Vinniks

        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the License.
        You may obtain a copy of the License at

            http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.
    */

    v_schemas t_varchars;
    v_root_node t_persistent_json := t_persistent_json('$');

    PROCEDURE register_messages IS
    BEGIN
        default_message_resolver.register_message('DOM-00001', 'Root node is not an object!');
        default_message_resolver.register_message('DOM-00002', ':1 :2.:3 does not exist or is not accessible!');
        default_message_resolver.register_message('DOM-00003', 'Database object model for :1 is not supported!');
        default_message_resolver.register_message('DOM-00004', 'Database object model for :1 :2.:3 successfully updated.');
        default_message_resolver.register_message('DOM-00005', 'Database object model for :1 :2.:3 could not be found!');
        default_message_resolver.register_message('DOM-00006', 'Database object root could not be found!');
    END;

    FUNCTION load_package_dom_json (
        p_owner IN VARCHAR2,
        p_name IN VARCHAR2
    )
    RETURN CLOB
    AS LANGUAGE JAVA NAME 'DatabaseObjectResolverAPI.loadPackageDOM(java.lang.String, java.lang.String) return java.sql.Clob';
    
    FUNCTION get_object_node (
        p_parent_node IN t_json,
        p_name IN VARCHAR2
    )
    RETURN t_json IS
        v_node t_json;
    BEGIN
    
        v_node := p_parent_node.get(':name', bind(p_name));
        
        IF v_node IS NULL OR NOT v_node.is_object THEN
            RETURN p_parent_node.set_object(':name', bind(p_name));
        ELSE
            RETURN v_node;
        END IF;
    
    END;
    
    PROCEDURE set_schemas (
        p_schemas IN t_varchars
    ) IS
    BEGIN
        v_schemas := p_schemas;
    END;
    
    FUNCTION load_json (
        p_schema IN STRINGN,
        p_object_type IN STRINGN,
        p_object_name IN STRINGN
    )
    RETURN CLOB IS
        v_dummy NUMBER;
    BEGIN
        
        BEGIN
        
            SELECT 1
            INTO v_dummy
            FROM all_objects
            WHERE owner = p_schema
                  AND object_type = p_object_type
                  AND object_name = p_object_name;
                  
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- :1 :2.:3 does not exist or is not accessible
                error$.raise('DOM-00002', p_object_type, p_schema, p_object_name);
        END;
        
        CASE p_object_type
            WHEN 'PACKAGE' THEN
                RETURN load_package_dom_json(p_schema, p_object_name);
            ELSE
                -- Database object model for :1 is not supported!
                error$.raise('DOM-00003', p_object_type);
        END CASE;
        
    END;

    FUNCTION load (
        p_schema IN STRINGN,
        p_object_type IN STRINGN,
        p_object_name IN STRINGN
    )
    RETURN t_json IS
        v_object_dom_json CLOB;
        v_object_dom t_json;
    BEGIN
    
        v_object_dom_json := load_json(p_schema, p_object_type, p_object_name);
        v_object_dom := t_transient_json.create_json(v_object_dom_json);
        DBMS_LOB.FREETEMPORARY(v_object_dom_json);
        
        RETURN v_object_dom;
        
    END;

    PROCEDURE build (
        p_raise_exception IN BOOLEAN := TRUE
    )IS
    BEGIN
        NULL;
    END;

    PROCEDURE build (
        p_schema IN STRINGN,
        p_raise_exception IN BOOLEAN := TRUE
    ) IS
    
        CURSOR c_objects IS
            SELECT object_type,
                   object_name
            FROM all_objects
            WHERE owner = p_schema
                  AND object_type IN ('PACKAGE');
        
    BEGIN
        
        FOR v_object IN c_objects LOOP
            build(p_schema, v_object.object_type, v_object.object_name, p_raise_exception);
        END LOOP;
    
    END;
    
    PROCEDURE build (
        p_schema IN STRINGN,
        p_object_type IN STRINGN,
        p_raise_exception IN BOOLEAN := TRUE
    ) IS
        
        CURSOR c_objects IS
            SELECT object_name
            FROM all_objects
            WHERE owner = p_schema
                  AND object_type = p_object_type;
        
    BEGIN
        
        FOR v_object IN c_objects LOOP
            build(p_schema, p_object_type, v_object.object_name, p_raise_exception);
        END LOOP;
    
    END;
    
    PROCEDURE build (
        p_schema IN STRINGN,
        p_object_type IN STRINGN,
        p_object_name IN STRINGN,
        p_raise_exception IN BOOLEAN := TRUE
    ) IS
        v_parent_node t_json;
        v_attribute_name STRING;
        v_object_dom t_json;
    BEGIN
    
        log$.call()
            .value('p_schema', p_schema)
            .value('p_object_type', p_object_type)
            .value('p_object_name', p_object_name)
            .value('p_raise_exception', p_raise_exception);
    
        v_parent_node := get_object_node(v_root_node, '__dom');
        v_parent_node := get_object_node(v_parent_node, p_schema);
        
        IF p_object_type = 'PACKAGE' THEN
            v_parent_node := get_object_node(v_parent_node, 'packages');
            v_parent_node := get_object_node(v_parent_node, p_object_name);
            v_attribute_name := 'specification';
        ELSE
            -- Database object model for :1 is not supported!
            error$.raise('DOM-00003', p_object_type);
        END IF; 
        
        BEGIN
            v_object_dom := load(p_schema, p_object_type, p_object_name);
        EXCEPTION
            WHEN OTHERS THEN
                IF p_raise_exception THEN
                    error$.raise;
                ELSE
                    error$.handle;
                    RETURN;
                END IF;
        END; 
            
        v_parent_node.set_json(':name', v_object_dom, bind(v_attribute_name));
        
        -- Database object model for :1 :2.:3 successfully updated.
        log$.info('DOM-00004', p_object_type, p_schema, p_object_name);  
        
    END;
    
    FUNCTION get
    RETURN t_json IS
        v_root t_json;
    BEGIN
    
        v_root := v_root_node.get('__dom');
        
        IF v_root IS NULL THEN
            -- Database object root could not be found!
            error$.raise('DOM-00006');
        END IF; 
        
        RETURN v_root;
        
    END;
    
    FUNCTION get (
        p_schema IN STRINGN,
        p_object_type IN STRINGN,
        p_object_name IN STRINGN
    )
    RETURN t_json IS
        v_node t_json;
    BEGIN
    
        v_node := v_root_node.get('__dom.:schema', bind(p_schema));
        
        IF v_node IS NULL THEN
            -- Database object model for :1 :2.:3 could not be found!
            error$.raise('DOM-00005', p_object_type, p_schema, p_object_name);
        END IF;
        
        IF p_object_type = 'PACKAGE' THEN
            v_node := v_node.get('packages.:name.specification', bind(p_object_name));
        ELSE
            -- Database object model for :1 is not supported!
            error$.raise('DOM-00003', p_object_type);
        END IF;
        
        IF v_node IS NULL THEN
            -- Database object model for :1 :2.:3 could not be found!
            error$.raise('DOM-00005', p_object_type, p_schema, p_object_name);
        END IF;
        
        RETURN v_node;
    
    END;
    
BEGIN
    register_messages;    
END;
