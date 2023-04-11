#include <amxmisc>
#include <fakemeta>
#include <sqlx>

#pragma semicolon 1

#define SZPREFIX "!g[AMXX]!y"

enum _:MESSAGEMODE_STRUCT
{
	REGISTRAR_PASSWORD,
	CONFIRMAR_PASSWORD,
	INGRESAR_PASSWORD
};

// TABLA Y BASE DE DATOS
#define SQL_TABLE "SQL_MyTable"
#define SQL_DATABASE "SQL_DBTest"

/* ================================================== */
/* 
	CREAMOS LAS VARIABLES QUE SERÁN UTILIZADAS, GUARDADAS Y / O CARGADAS. 
	EN ESTE CASO EL REGISTRO SERÁ POR NOMBRE DE USUARIO, PERO GUARDAREMOS / CARGAREMOS POR EL ID DEL USUARIO.
*/

new g_user_name[33][32]; // NOMBRE DEL USUARIO - SERÁ UNA CADENA DE 32 DÍGITOS.
new g_user_password[33][32]; // CONTRASEÑA DEL USUARIO - SERÁ UNA CADENA DE 32 DÍGITOS.
new g_user_register[33]; // ESTADO DEL USUARIO (SI ESTÁ REGISTRADO O NO).
new g_user_logged[33]; // ESTADO DEL USUARIO (SI ESTÁ LOGUEADO O NO).
new g_user_auto_logged[33]; // ESTADO DEL USUARIO (SI ESTÁ AUTOLOGUEADO O NO).
new g_user_id[33]; // ID DEL USUARIO.
new g_user_date_register[33][32]; // FECHA DE REGISTRO.
new g_user_last_date[33][32]; // ÚLTIMO INGRESO DEL USUARIO AL SERVIDOR.
new g_frags[33]; // FRAGS DEL USUARIO.
new g_death[33]; // MUERTES DEL USUARIO.
/* ================================================== */

new g_messagemode[33];
new g_maxplayers;

/* ================================================== */
/*
	VARIABLES PARA CONECTAR / OBTENER INFORMACIÓN DE LA BASE DE DATOS.
*/
new Handle:g_sql_connection; // Variable que abrirá conexión con la base de datos.
new Handle:g_sql_htuple; // Variable que almacenará información de la conexión (No se conecta a la base de datos).
/* ================================================== */

public plugin_init()
{
	register_plugin("[GUÍA] System Account", "1.0", "Cristian'");
	
	register_clcmd("chooseteam", "clcmd_changeteam");
	register_clcmd("jointeam", "clcmd_changeteam");
	register_clcmd("REGISTRAR_PASSWORD", "clcmd_messagemode");
	register_clcmd("CONFIRMAR_PASSWORD", "clcmd_messagemode");
	register_clcmd("INGRESAR_PASSWORD", "clcmd_messagemode");
	
	register_clcmd("say /frags", "clcmd_frags");
	
	register_forward(FM_ClientUserInfoChanged, "fm_ClientUserInfoChanged"); // Evitamos que el usuario se cambie de nombre.
	
	register_event("HLTV", "event_HLTV", "a", "1=0", "2=0");
	register_event("DeathMsg", "event_DeathMsg", "a");
	
	g_maxplayers = get_maxplayers(); // Obtenemos en la variable g_maxplayers la cantidad de clientes que hay en el servidor
	
	sqlx_init(); // Llamamos a la función que conectará la base de datos y creará la tabla.
}

public client_putinserver(id)
{
	// Reseteamos sus valores
	get_user_name(id, g_user_name[id], 31);
	
	g_user_register[id] = 0;
	g_user_logged[id] = 0;
	g_user_auto_logged[id] = 0;
	g_frags[id] = 0;
	g_death[id] = 0;
	
	g_user_password[id][0] = EOS;
	g_user_date_register[id][0] = EOS;
	g_user_last_date[id][0] = EOS;
		
	set_task(0.1, "user_check", id); // Llamamos a la función "user_check" en un lapso de 0.1 segundos para seleccionar los datos del usuario que ingresó al servidor.
}

public client_disconnect(id)
{
	// Si el usuario logueado se desconecta del servidor, llamamos a la función que ejecutará la consulta para guardar sus datos.
	if (g_user_logged[id])
	{
		save_data(id);
		g_user_logged[id] = 0;
	}	
}

public event_HLTV()
{
	new id;
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (g_user_logged[id]) // Si el usuario está logueado, le  guardamos sus datos.
			save_data(id); // Si es una nueva ronda, llamamos a la función que ejecutará la consulta para guardar sus datos.
	}
}

public event_DeathMsg()
{
	static attacker, victim;
	attacker = read_data(0);
	victim = read_data(1);
	
	g_frags[attacker]++;
	g_death[victim]++;
}

public clcmd_frags(id)
{
	chat_color(id, "%s !yFrags: !g%d!y | Muertes: !g%d!y.", SZPREFIX, g_frags[id], g_death[id]);
	return PLUGIN_HANDLED;
}

public user_check(id)
{
	if (!is_user_connected(id)) // Si no está conectado detenemos el complemento.
		return PLUGIN_HANDLED;
	
	/*
		* Lógica de la consulta: SELECCIONAR id, password, ip, date_register, last_date DE 'tabla' DONDE name = 'mi_name';
		* El ";" es utilizado para separar las consultas.
	
	*/
	
	// Preparamos la consulta
	new Handle:query;
	query = SQL_PrepareQuery(g_sql_connection, "SELECT id, password, ip, date_register, last_date FROM '%s' WHERE name = ^"%s^";", SQL_TABLE, g_user_name[id]);
	
	// Ejecutamos la consulta que anteriormente preparamos (SQL_PrepareQuery).
	if (!SQL_Execute(query)) // Si la consulta no es válida 
	{
		SQL_FreeHandle(query); // Liberamos el identificador de la consulta.
		sql_query_error(id, query);
	}
	else if (SQL_NumResults(query)) // Si la consulta arroja resultados
	{
		/*
			* Si seleccionamos los datos individualmente y no todos (*) el SQL_ReadResult comenzaría en 0.
			* Ejemplo: SELECT id, password, ip, date_register, last_date (0, 1, 2, 3, 4).
		*/
		
		g_user_register[id] = 1; // Ponemos que el usuario está registrado.
		
		new ip[21], dbip[21];
		get_user_ip(id, ip, 20, 1); // Obtenemos la IP del usuario.
		
		g_user_id[id] = SQL_ReadResult(query, 0); // Obtenemos el ID del usuario de la base de datos.
		SQL_ReadResult(query, 1, g_user_password[id], 31);  // Obtenemos la CONTRASEÑA de la base de datos que luego será verificada al ingresar la contraseña en una nueva cadena.
		SQL_ReadResult(query, 2, dbip, 20); // Obtenemos la IP de la base de datos.
		SQL_ReadResult(query, 3, g_user_date_register[id], 31); // Obtenemos la fecha de registro de la base de datos.
		SQL_ReadResult(query, 4, g_user_last_date[id], 31); // Obtenemos la última vez que ingresó de la base de datos.
		
		if (equali(ip, dbip)) // Si la IP del USUARIO es igual a la IP de la BASE DE DATOS.
			g_user_auto_logged[id] = 1; // Ponemos que está auto logueado.
		
		
		SQL_FreeHandle(query); // Liberamos el identificador de la consulta.
	}
	else 
		SQL_FreeHandle(query); // Liberamos el identificador de la consulta.
	
	clcmd_changeteam(id);
	return PLUGIN_HANDLED;
}

public clcmd_changeteam(id)
{
	/* ========================= */
	// SI EL USUARIO ESTÁ LOGUEADO, HACEMOS QUE EL COMPLEMENTO DE LA FUNCIÓN DE ELECCIÓN DE EQUIPO CONTINÚE CON NORMALIDAD.
	if (g_user_logged[id])
		return PLUGIN_CONTINUE;
	/* ========================= */
	
	/* ========================= */
	/*
		* COMO HEMOS DICHO ANTERIORMENTE, SI EL USUARIO ESTABA LOGUEADO (VER ARRIBA) CONTINUAMOS EL VALOR DE LA FUNCIÓN CON NORMALIDAD.
		* SI NO LO ESTÁ, LE MOSTRAMOS EL REGISTRO Y DETENEMOS EL COMPLEMENTO DE DICHA FUNCIÓN.
	*/
	
	show_menu_register(id); // Función que tendrá el registro del usuario.
	return PLUGIN_HANDLED; // Detiene le complemento de la función.
}


show_menu_register(id)
{
	static menu, sztext[128];
	menu = menu_create("\yMENÚ DE REGISTRO", "handled_show_menu_register");
	
	if (!g_user_auto_logged[id]) // Si el usuario no está auto logueado, le mostramos el registro
	{
		menu_additem(menu, "REGISTRARSE", "1", _, menu_makecallback("menu_makecallback_register"));
		menu_additem(menu, "LOGUEARME", "2", _, menu_makecallback("menu_makecallback_login"));
	}
	else
		menu_additem(menu, "INGRESAR AL SERVIDOR", "1");
		
	
	if (g_user_register[id]) // Si el usuario está registrado le mostramos el número de #REGISTRO de su cuenta, la fecha de registro y el último ingreso.
	{
		format(sztext, 127, "^n\wCuenta número: \y#%d^n^n\wFecha de registro: \y%s^n\wÚltimo ingreso al servidor: \y%s", 
		g_user_id[id], g_user_date_register[id], (g_user_last_date[id][0]) ? g_user_last_date[id] : "-");
		menu_addtext(menu, sztext);
	}
	
	menu_setprop(menu, MPROP_EXIT, -1);
	
	menu_display(id, menu, .page = 0, .time = -1);
}

public menu_makecallback_register(id, menu, item)
	return (g_user_register[id]) ? ITEM_DISABLED : ITEM_ENABLED;

public menu_makecallback_login(id, menu, item)
	return (g_user_register[id]) ? ITEM_ENABLED : ITEM_DISABLED;	
	
public handled_show_menu_register(id, menu, item)
{
	switch(item)
	{
		case MENU_EXIT: 
		{
			menu_destroy(menu); 
			return PLUGIN_HANDLED;
		}
		case 0: 
		{
			if (g_user_auto_logged[id])
			{
				enter_user(id);
				return PLUGIN_HANDLED;
			}
			
			client_cmd(id, "messagemode REGISTRAR_PASSWORD"), g_messagemode[id] = REGISTRAR_PASSWORD;
		}
		case 1: client_cmd(id, "messagemode INGRESAR_PASSWORD"), g_messagemode[id] = INGRESAR_PASSWORD;
	}
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public clcmd_messagemode(id)
{
	/* ================================================= */
		/*
			VERIFICAMOS QUE EL USUARIO ESTÉ LOGUEADO 
			PARA EVITAR QUE PUEDA BUGUEAR LOS MESSAGEMODES 
			(REGISTRARSE / LOGUEARSE) A TRAVÉS DE CONSOLA.
			EN CASO DE ESTARLO, DETENEMOS EL COMPLEMENTO 
			DE LA FUNCIÓN.
		*/
	/* ================================================= */
	
	if (g_user_logged[id])
		return PLUGIN_HANDLED;
	
	static args[28];
	read_args(args, 27); // Obtenemos la cadena que puso en consola. 
	remove_quotes(args); // Removemos las comillas "".
	trim(args); // Eliminamos los espacios en blanco del principio a final de la cadena.
	
	switch(g_messagemode[id])
	{
		case REGISTRAR_PASSWORD:
		{
			// Verificamos que el usuario esté registrado para detener el complemento de la función.
			if (g_user_register[id])
				return PLUGIN_HANDLED;
			
			// Calculamos la longitud de la cadena introducda, en este caso si la cadena posee menos de 4 dígitos
			// detenemos el complemento.
			if (strlen(args) < 4)
			{
				client_print(id, print_center, "LA CONTRASEÑA DEBE CONTENER MÁS DE 4 DÍGITOS");
				return PLUGIN_HANDLED;
			}
			
			// Si puso más de 4 dígitos, hacemos que confirme su contraseña.
			g_messagemode[id] = CONFIRMAR_PASSWORD;
			client_cmd(id, "messagemode CONFIRMAR_PASSWORD");
			copy(g_user_password[id], 31, args);
		}
		case CONFIRMAR_PASSWORD:
		{
			// Verificamos que el usuario esté registrado para detener el complemento de la función.
			if (g_user_register[id])
				return PLUGIN_HANDLED;
			
			// Verificamos si la contraseña que introdujo sea igual a la que puso al REGISTRAR_PASSWORD.
			// Si no es igual, detenemos el complemento de la función.
			if (!equali(g_user_password[id], args))
			{
				client_print(id, print_center, "La contraseña introducia no coincide");
				return PLUGIN_HANDLED;
			}
			
			// Si no se detuvo el complemento anteriormente (LA CONTRASEÑA ES IGUAL), insertamos sus datos en la base de datos.
			
			/*
				* INSERT INTO: Se utiliza para insertar un nuevo registro en la tabla.
				* Quedaría de esta manera la lógica: INSERTAR EN 'tabla' (columna1, column2, column3) VALORES (valor1, valor2, valor3); 
			*/
			
			// Preparamos la consulta, que contendrá el nombre, la contraseña, y la fecha de registro
			new Handle:query, time[32];
			get_time("%d/%m/%Y - %H:%M:%S", time, 31); // Obtenemos la fecha %days/%month/%year - %hour:%minutes/%seconds
			
			query = SQL_PrepareQuery(g_sql_connection, "INSERT INTO '%s' (name, password, date_register) VALUES (^"%s^", ^"%s^", ^"%s^")", 
			SQL_TABLE, g_user_name[id], g_user_password[id], time);
		
			// Ejecutamos la consulta que anteriormente preparamos (SQL_PrepareQuery).
			
			if (!SQL_Execute(query)) // Si la consulta ejecutada no es válida.
			{
				sql_query_error(id, query);
				SQL_FreeHandle(query); // Liberamos el identificador de la consulta.
			}
			else // Si es válida
			{
				SQL_FreeHandle(query); // Liberamos el identificador de la consulta para realizar otra.
				
				// Preparamos la consulta para seleccionar el ID del usuario.
				query = SQL_PrepareQuery(g_sql_connection, "SELECT id FROM '%s' WHERE name = ^"%s^"", SQL_TABLE, g_user_name[id]);
				
				if (!SQL_Execute(query)) // Si la consulta no es válida.
				{
					sql_query_error(id, query);
					SQL_FreeHandle(query); // Liberamos el identificador de la consulta.
				}
				else if (SQL_NumResults(query)) // Si la consulta arroja resultados
				{
					// Obtenemos en la variable g_user_id el #ID del usuario para que se autoincremente 
					// y no se buguee al guardar sus datos ya que estamos guardando sus datos por el #ID
					// y por defecto la variable del #ID del usuario es 0.
					
					g_user_id[id] = SQL_ReadResult(query, 0);
					
					g_user_register[id] = 1; // Si el usuario se registró con éxito, ponemos que está registrado.
					g_user_logged[id] = 1; // Si el usuario se registró con éxito, ponemos que está logueado.
					
					chat_color(id, "%s !yBienvenido !t%s!y, sos la cuenta registrada número !g#%d!y.", SZPREFIX, g_user_name[id], g_user_id[id]);
					SQL_FreeHandle(query); // Liberamos el identificador de la consulta.
				}
				else
					SQL_FreeHandle(query); // Liberamos el identificador de la consulta.
			}
		}
		case INGRESAR_PASSWORD:
		{
			// Verificamos que el usuario no esté registrado para detener el complemento de la función.
			if (!g_user_register[id])
				return PLUGIN_HANDLED;
			
			// Si la contraseña que puso no es igual a la contraseña cargada, detenemos el complemento
			if (!equali(g_user_password[id], args))
			{
				chat_color(id, "%s !yTu contraseña no coincide.", SZPREFIX);
				return PLUGIN_HANDLED;
			}
			
			enter_user(id); // Función que lo hará ingresar al servidor.
		}
	}
	
	
	client_cmd(id, "chooseteam");
	return PLUGIN_HANDLED;
}

enter_user(id)
{
	// Preparamos la consulta.
	new Handle:query, ip[21], time[32];
	
	get_time("%d/%m/%Y - %H:%M:%S", time, 31); // Obtenemos la fecha %days/%month/%year - %hour:%minutes/%seconds
	get_user_ip(id, ip, 21, 1); // Obtenemos la ip del usuario
	
	// Preparamos la consulta para guardar su ip y la fecha de ingreso.
	query = SQL_PrepareQuery(g_sql_connection, "UPDATE '%s' SET last_date = ^"%s^", ip = ^"%s^" WHERE id = '%d';", SQL_TABLE, time, ip, g_user_id[id]);
	
	if (!SQL_Execute(query)) // Si la consulta no es válida.
	{
		sql_query_error(id, query);
		SQL_FreeHandle(query); // Liberamos el identificador de la consulta.
	}
	else // Si es válida, liberamos el identificador de la consulta.
		SQL_FreeHandle(query);
		
	g_user_logged[id] = 1; // Si el usuario puso su contraseña correctamente, ponemos que está logueado y le cargamos sus datos.
	chat_color(id, "%s !yBienvenido !g%s!y.", SZPREFIX, g_user_name[id]);
	load_data(id); // Llamamos a la función que ejecutará la consulta y cargará sus datos.
	
	client_cmd(id, "chooseteam");
}

save_data(id)
{
	/*
		* UTILIZAMOS ThreadQuery PARA GUARDAR SUS DATOS
		* YA QUE PrepareQuery CORRE CON EL MISMO PROCESO 
		* DEL SERVIDOR Y PUEDE GENERAR QUE SE CONGELE.
	*/
	
	
	/*
		* PREPARAMOS LA CONSULTA, UTILIZAMOS LA TUPLA QUE NOS DEVOLVIÓ SQL_MakeDbTuple().
		SQL_ThreadQuery(Handle:Tupla, "función", "consulta", index);
	*/
	
	
	static save[128], data[2];
	data[0] = id; 
	data[1] = 1;

	/*
		* Lógica de la consulta: ACTUALIZAR 'mi_tabla' CONJUNTO frags = '%d', deaths = '%d' DONDE id = '%d';
		* El ";" es utilizado para separar consultas.
	
	*/
	
	format(save, 127, "UPDATE '%s' SET frags = '%d', deaths = '%d' WHERE id = '%d';", SQL_TABLE, g_frags[id], g_death[id], g_user_id[id]);
	
	SQL_ThreadQuery(g_sql_htuple, "SQL_DataHandled", save, data, 2);
}


public SQL_DataHandled(failstate, Handle:query, error[], errnum, data[], size, Float:queutime)
{
	/* 
		* failstate: Una de las 3 consultas lo define.
			- TQUERY_CONNECT_FAILED.
			- TQUERY_QUERY_FAILED.
			- TQUERY_SUCCESS.
		
		* Handle:query: Maneja la consulta, no debe ser liberada.
		* const error[]: Devuelve un mensaje de error si es que lo hay.
		* errnum: Devuelve un código de error si es lo que hay.
		* const data[]: matriz de datos ingresados.
		* size: tamaño de la matriz ingresada,
		* queutime: El tiempo que pasó mientras la consulta era ejecutada.
	*/
	
	
	if (failstate == TQUERY_CONNECT_FAILED || failstate == TQUERY_QUERY_FAILED)
	{
		sql_query_error(data[0], query);
		return PLUGIN_HANDLED;
	}
	
	if (data[1])
	{
		if (failstate != TQUERY_SUCCESS) // Si el failstate no es igual 0 (TQUERY_SUCCESS) detenemos el complemento.
			return PLUGIN_HANDLED;
		
		chat_color(data[0], "%s !yTus datos fueron almacenados.", SZPREFIX);
	}
	
	return PLUGIN_HANDLED;
}

load_data(id)
{
	/*
		* Lógica de la consulta: SELECCIONAR * (TODO) DE 'tabla' DONDE id = 'mi_id';
		* El ";" es utilizado para separar las consultas.
	
	*/
	
	// Preparamos la consulta y cargamos sus datos por el ID del usuario
	new Handle:query;
	query = SQL_PrepareQuery(g_sql_connection, "SELECT * FROM '%s' WHERE id = '%d';", SQL_TABLE, g_user_id[id]);
	
	// Ejecutamos la consulta que anteriormente preparamos (SQL_PrepareQuery).
	if (!SQL_Execute(query)) // Si la consulta no es válida 
	{
		SQL_FreeHandle(query); // Liberamos el identificador de la consulta.
		sql_query_error(id, query);
	}
	else if (SQL_NumResults(query)) // Si la consulta arroja resultados 
	{
		/*
			NOTA: Al seleccionar todos los datos (*), si solamente queremos obtener los frags y muertes del usuario.
			deberíamos tener en cuenta las columnas anteriores, Un pequeño ejemplo numérico de nuestra tabla:
			
			ID = 0,
			NOMBRE = 1
			PASSWORD = 2
			DATE_REGISTER = 3
			LAST_DATE = 4
			IP = 5
			FRAGS = 6
			DEATHS = 7
		*/
		
		// Cargamos sus datos
		g_frags[id] = SQL_ReadResult(query, 6); // Recuperamos en la variable g_frags el resultado actual de la columna Nº 6.
		g_death[id] = SQL_ReadResult(query, 7); // Recuperamos en la variable g_death el resultado actual de la columna Nº 7.
		
		SQL_FreeHandle(query); // Liberamos el identificador de la consulta.
	}	
	else // Si no arroja resultados, liberamos el identificador de la consulta.
		SQL_FreeHandle(query);
}

sql_query_error(id, Handle:query)
{
    static error[56];
    SQL_QueryError(query, error, 55); // Obtenemos la información de la consulta errónea.
        
    chat_color(id, "%s !yError: !g%s!y.", SZPREFIX, error); // Le mandamos al usuario el mensaje con la consulta errónea.
    SQL_FreeHandle(query); // Liberamos el identificador de la consulta.
}

sqlx_init()
{
	new error, errorcode[128];
	
	// Si el módulo sqlite no está cargado, detenemos el complemento.
	if (!module_exists("sqlite"))
	{
		log_to_file("SQL_Module.txt", "El módulo ^"sqlite^" es necesario.", SZPREFIX);
		return PLUGIN_HANDLED;
	}
	
	/* SQL_MakeDbTuple
	(
		"", | Base de datos host.
		"", | Usuario de la base de datos.
		"", | Contraseña de la base de datos.
		SQL_DATABASE, | Nombre de la base de datos.
		TIMEOUT | Tiempo de espera de la conexión antes de cerrarse.
	);
		
	*/
	g_sql_htuple = SQL_MakeDbTuple("", "", "", SQL_DATABASE, .timeout = 0); // Creamos una tupla de información de conexión.
	
	
	/* SQL_Connect
	(
		Handle:tupla, | INFORMACIÓN DE CONEXIÓN DEVUELTA POR SQL_MakeDbTuple
		error, | Cadena donde se almacenará la cadena error.
		errorcode, | Código del error.
		127, | Longitud de la cadena.
	)
	*/
	g_sql_connection = SQL_Connect(g_sql_htuple, error, errorcode, 127); // Abrimos una conexión  con la base de datos.
	
	if (g_sql_htuple == Empty_Handle)
	{
		log_to_file("SQL_Htuple.txt", "Error en la tupla");
		return PLUGIN_HANDLED;
	}
	
	if (g_sql_connection == Empty_Handle)
	{
		log_to_file("SQL_Connection.txt", "Error al conectar base de datos %s (%s)", error, errorcode);
		return PLUGIN_HANDLED;
	}
	
	/*
		Preparamos la consulta que creará nuestra tabla (No es recomendable hacerlo dentro del plugin, para eso existen varios programas).
		
		* INTEGER: Permite números enteros.
		* PRIMARY KEY: Identifica de forma única cada registro en una tabla de base de datos.
		* AUTOINCREMENT: Permite que se genere automáticamente un número  cuando se inserta un registro, en este caso se genera el campo #ID.
		* UNIQUE: Asegura que todos los valores de una columna sean diferentes, al igual que la restricción PRIMARY KEY, en este caso el NOMBRE.
		* VARCHAR: Permite una cadena de carácteres.
	*/
	
	new Handle:query;
	query = SQL_PrepareQuery
	(
		g_sql_connection, 
		"CREATE TABLE IF NOT EXISTS '%s'  \
		( \
			id INTEGER PRIMARY KEY AUTOINCREMENT, \
			name VARCHAR(32) NOT NULL UNIQUE, \
			password VARCHAR(32) NOT NULL, \
			date_register VARCHAR(32) NOT NULL DEFAULT '', \
			last_date VARCHAR(32) NOT NULL NOT NULL DEFAULT '', \
			ip VARCHAR(21) NOT NULL DEFAULT '', \
			frags INTEGER NOT NULL DEFAULT '0', \
			deaths INTEGER NOT NULL DEFAULT '0' \
		)", SQL_TABLE
	);
	
	if (!SQL_Execute(query))
	{
		sql_query_error(0, query);
		SQL_FreeHandle(query);
	}
	else
		SQL_FreeHandle(query);
	
	return PLUGIN_HANDLED;
}

public fm_ClientUserInfoChanged(id, info)
{
	if (!is_user_connected(id)) // Si el usuario no está conectado, hacemos que la función continúe con normalidad.
		return FMRES_IGNORED;
	
	static name[32];
	get_user_info(id, "name", name, 31); // Obtenemos la información del usuario, en este caso del nombre.
	
	if (equal(g_user_name[id], name)) // Si el nombre que ingresó es igual al nombre que tiene, hacemos que la función continúe con normalidad.
		return FMRES_IGNORED; // 
	
	set_user_info(id, "name", g_user_name[id]); // Le ingresamos la información de la cadena del nombre que se almacenó en la variable al conectarse.
	return FMRES_SUPERCEDE; // Detenemos el complemento.
}

chat_color(id, const input[], any:...)
{
    static message[191];
    vformat(message, 190, input, 3);
    
    replace_all(message, 190, "!g", "^4");
    replace_all(message, 190, "!t", "^3");
    replace_all(message, 190, "!y", "^1");
    
    message_begin((id) ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, get_user_msgid("SayText"), .player = id);
    write_byte((id) ? id : 33);
    write_string(message);
    message_end();
}

public plugin_end()
{
	SQL_FreeHandle(g_sql_connection); // Liberamos la conexión.
	SQL_FreeHandle(g_sql_htuple); // Liberamos la información obtenida.
}