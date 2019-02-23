CREATE OR REPLACE PACKAGE dom IS

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

    SUBTYPE STRING IS
        VARCHAR2(32767);
        
    SUBTYPE STRINGN IS
        STRING NOT NULL;

    PROCEDURE set_schemas (
        p_schemas IN t_varchars
    );

    FUNCTION load_json (
        p_schema IN STRINGN,
        p_object_type IN STRINGN,
        p_object_name IN STRINGN
    )
    RETURN CLOB;

    FUNCTION load (
        p_schema IN STRINGN,
        p_object_type IN STRINGN,
        p_object_name IN STRINGN
    )
    RETURN t_json;

    PROCEDURE build (
        p_raise_exception IN BOOLEAN := TRUE
    );

    PROCEDURE build (
        p_schema IN STRINGN,
        p_raise_exception IN BOOLEAN := TRUE
    );
    
    PROCEDURE build (
        p_schema IN STRINGN,
        p_object_type IN STRINGN,
        p_raise_exception IN BOOLEAN := TRUE
    );
    
    PROCEDURE build (
        p_schema IN STRINGN,
        p_object_type IN STRINGN,
        p_object_name IN STRINGN,
        p_raise_exception IN BOOLEAN := TRUE
    );
    
    FUNCTION get
    RETURN t_json;
    
    FUNCTION get (
        p_schema IN STRINGN,
        p_object_type IN STRINGN,
        p_object_name IN STRINGN
    )
    RETURN t_json;
    
END;